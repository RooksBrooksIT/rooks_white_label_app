/**
 * Cloud Function: createPaymentSession
 * Production Version: 12.0.0
 */

"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const iciciService = require("./icici_service");
const axios = require("axios");

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

exports.createPaymentSession = onRequest(
    {
        region: "us-central1",
        vpcConnector: "icici-connector",
        vpcConnectorEgressSettings: "ALL_TRAFFIC",
        cors: true,
        timeoutSeconds: 60,
        memory: "256MiB",
        invoker: "public",
    },
    async (req, res) => {
        const TAG = "[CREATE-SESSION]";
        
        try {
            // Log Public IP for debugging
            try {
                const ipRes = await axios.get("https://api.ipify.org?format=json");
                console.log(`${TAG} PUBLIC OUTBOUND IP: ${ipRes.data.ip}`);
            } catch (ipErr) {
                console.error(`${TAG} IP-FETCH-ERROR:`, ipErr.message);
            }

            if (req.method !== "POST") {
                return res.status(405).json({ success: false, error: "Method not allowed" });
            }

            const { amount, userId, paymentMode, planName, email, mobile, tenantId, appId } = req.body;

            // 1. Strict Validation
            if (!amount || !userId || !paymentMode || !tenantId || !appId) {
                return res.status(400).json({ success: false, error: "Missing required integration parameters" });
            }

            const normMode = String(paymentMode).trim().toUpperCase();
            
            // 2. Secure Transaction ID Generation
            // Rule: 20 chars max for ICICI, Secure random
            const randomSuffix = crypto.randomBytes(4).toString("hex").toUpperCase();
            const txnId = `RB${Date.now().toString().slice(-8)}${randomSuffix}`.substring(0, 20);

            console.log(`${TAG} Initializing ${normMode} for User: ${userId} | Txn: ${txnId}`);

            // 3. Prepare Firestore Document
            const paymentData = {
                txnId,
                userId,
                tenantId,
                appId,
                amount: parseFloat(amount),
                paymentMode: normMode,
                planName: planName || "Subscription",
                status: "PENDING",
                email: email || null,
                mobile: mobile || null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            await db.collection("payments").doc(txnId).set(paymentData);

            // 4. ICICI Service Call
            let result;
            if (normMode === "UPI") {
                result = await iciciService.generateUpiQr({ txnId, amount, email });
            } else {
                result = await iciciService.initiateSale({
                    txnId,
                    amount,
                    email,
                    paymentMode: normMode,
                    customerName: userId // Use userId as placeholder if name not provided
                });
            }

            // 5. Finalize Session
            if (result.success) {
                const updateData = {
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    redirectUrl: result.redirectUrl || null,
                    upiQR: result.upiUrl || null
                };
                
                await db.collection("payments").doc(txnId).update(updateData);

                return res.status(200).json({
                    success: true,
                    txnId,
                    paymentMode: normMode,
                    redirectUrl: result.redirectUrl,
                    upiQR: result.upiUrl
                });
            } else {
                await db.collection("payments").doc(txnId).update({
                    status: "FAILED",
                    error: result.error,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                return res.status(400).json({ success: false, txnId, error: result.error });
            }

        } catch (error) {
            console.error(`${TAG} FATAL:`, error);
            return res.status(500).json({ success: false, error: "Payment Session Initialization Failed" });
        }
    }
);