/**
 * ICICI Payment Webhook & Status Functions
 * Production Version: 12.0.0
 */

"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const iciciService = require("./icici_service");

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * Webhook: paymentCallback
 * Securely processes bank notifications
 */
exports.paymentCallback = onRequest(
    { cors: true, timeoutSeconds: 60, invoker: "public" },
    async (req, res) => {
        const TAG = "[CALLBACK]";
        const data = req.body;
        
        // Log basic info, avoid sensitive data in production
        const txnId = data.ORDER_ID || data.merchantRefNo || data.merchantTxnNo;
        console.log(`${TAG} Received for TXN: ${txnId}`);

        if (!txnId) return res.status(400).send("Missing ID");

        try {
            // 1. Fetch transaction from Firestore
            const paymentRef = db.collection("payments").doc(txnId);
            
            await db.runTransaction(async (transaction) => {
                const doc = await transaction.get(paymentRef);
                if (!doc.exists) throw new Error(`Transaction ${txnId} not found`);

                const paymentData = doc.data();

                // 2. Idempotency Check
                if (paymentData.status === "SUCCESS") {
                    console.log(`${TAG} Already processed SUCCESS for ${txnId}`);
                    return; 
                }

                // 3. Security Verification (Verify amount and MID)
                const bankAmount = parseFloat(data.TXN_AMOUNT || data.amount);
                if (Math.abs(bankAmount - paymentData.amount) > 0.01) {
                    console.error(`${TAG} Amount mismatch! DB: ${paymentData.amount}, Bank: ${bankAmount}`);
                    transaction.update(paymentRef, { 
                        status: "FAILED", 
                        error: "Amount mismatch",
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    return;
                }

                // 4. Force Status Verification with Bank API (Secure Practice)
                const verifyResult = await iciciService.statusCheck(txnId);
                if (!verifyResult.success) throw new Error("Could not verify status with bank API");

                const statusData = verifyResult.data;
                const respCode = statusData?.RESPONSE_CODE || statusData?.responseCode;

                let finalStatus = "FAILED";
                if (respCode === "0" || respCode === "00") {
                    finalStatus = "SUCCESS";
                } else if (respCode === "1" || respCode === "99") {
                    finalStatus = "FAILED";
                } else {
                    finalStatus = "PENDING"; // Still in process
                }

                // 5. Update Database
                const updateData = {
                    status: finalStatus,
                    iciciResponse: {
                        callback: data,
                        verification: statusData
                    },
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                };

                transaction.update(paymentRef, updateData);

                // 6. Mirror to Tenant Sub-collection
                if (finalStatus === "SUCCESS" && paymentData.tenantId && paymentData.appId) {
                    const tenantRef = db.doc(`${paymentData.tenantId}/${paymentData.appId}/payment_transactions/${txnId}`);
                    transaction.set(tenantRef, updateData, { merge: true });
                }
            });

            return res.status(200).send("OK");
        } catch (error) {
            console.error(`${TAG} Error:`, error.message);
            // Return 200 even on error to stop bank retries if we can't find the txn
            return res.status(200).send("Handled"); 
        }
    }
);

/**
 * API: verifyPayment
 * Client-side polling endpoint
 */
exports.verifyPayment = onRequest(
    { cors: true, invoker: "public" },
    async (req, res) => {
        const { txnId } = req.body;
        if (!txnId) return res.status(400).json({ success: false, error: "Missing txnId" });

        try {
            const verifyResult = await iciciService.statusCheck(txnId);
            if (!verifyResult.success) {
                return res.status(400).json({ success: false, error: verifyResult.error });
            }

            const data = verifyResult.data;
            const respCode = data?.RESPONSE_CODE || data?.responseCode;

            let status = "PENDING";
            if (respCode === "0" || respCode === "00") {
                status = "SUCCESS";
            } else if (respCode === "1" || respCode === "99") {
                status = "FAILED";
            }

            // Update DB if status changed
            if (status !== "PENDING") {
                await db.collection("payments").doc(txnId).update({
                    status: status,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            return res.status(200).json({ success: true, status, txnId });
        } catch (error) {
            return res.status(500).json({ success: false, error: error.message });
        }
    }
);

/**
 * API: processRefund
 * Initiates a reversal for a successful transaction
 */
exports.processRefund = onRequest(
    { cors: true, invoker: "public" },
    async (req, res) => {
        const { orderId, refundAmount } = req.body;
        if (!orderId || !refundAmount) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        try {
            const result = await iciciService.processRefund(orderId, refundAmount);
            if (result.success) {
                await db.collection("payments").doc(orderId).update({
                    status: "REFUNDED",
                    refundDetails: result.data,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                return res.status(200).json({ success: true, message: "Refund processed" });
            }
            return res.status(400).json({ success: false, error: "Refund rejected by bank", raw: result.data });
        } catch (error) {
            return res.status(500).json({ success: false, error: error.message });
        }
    }
);

