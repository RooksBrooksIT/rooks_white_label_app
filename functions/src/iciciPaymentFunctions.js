/**
 * ICICI Payment Gateway - Active Cloud Functions
 * ─────────────────────────────────────────────────────────────────────────────
 * Active functions:
 *   - processRefund      → Admin-triggered refund via ICICI Command API
 *   - paymentCallback    → Webhook called by ICICI after payment completion
 *
 * Superseded / removed:
 *   - initiatePayment    → Replaced by createPaymentSession
 *   - checkPaymentStatus → Flutter reads Firestore directly
 *   - createUpiOrder     → UPI now goes through createPaymentSession (WebView)
 *   - verifyUpiPayment   → No longer needed
 *   - testPaymentFlow    → Dev-only debug function, removed for production
 */

"use strict";

const { onRequest }      = require("firebase-functions/v2/https");
const admin              = require("firebase-admin");
const iciciService = require("./icici_service");
require("dotenv").config();

if (!admin.apps.length) {
  admin.initializeApp();
}

const db           = admin.firestore();
// Use standardized service from icici_service.js

// ─────────────────────────────────────────────────────────────────────────────
// 1. Process Refund
//    Called by Flutter admin panel (admin_transactions_screen.dart)
//    via IciciService.instance.initiateRefund()
// ─────────────────────────────────────────────────────────────────────────────
exports.processRefund = onRequest(
  {
    cors:           true,
    timeoutSeconds: 60,
    memory:         "256MiB",
  },
  async (req, res) => {
    const TAG = "[processRefund]";

    if (req.method !== "POST") {
      return res.status(405).json({ success: false, error: "Method not allowed. Use POST." });
    }

    // Auth guard
    const idToken = req.headers.authorization?.split("Bearer ")[1];
    if (!idToken) {
      return res.status(401).json({ success: false, error: "Unauthorized: no Bearer token." });
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      return res.status(401).json({ success: false, error: "Unauthorized: invalid token." });
    }

    const userId = decodedToken.uid;
    const { orderId, transactionId, refundAmount, customerId } = req.body;

    if (!orderId || !transactionId || !refundAmount) {
      return res.status(400).json({
        success: false,
        error:   "Missing required fields",
        required: ["orderId", "transactionId", "refundAmount"],
      });
    }

    console.log(`${TAG} Refund request | orderId=${orderId} | amount=${refundAmount} | user=${userId}`);

    // Verify the payment exists and is successful
    const paymentDoc = await db.collection("payments").doc(orderId).get();
    if (!paymentDoc.exists || paymentDoc.data().status !== "SUCCESS") {
      return res.status(400).json({
        success: false,
        error:   "Payment not found or not in SUCCESS state",
      });
    }

    try {
      const refundResult = await iciciService.processCommand({
        orderId,
        transactionId,
        command:         "REFUND_REQUEST",
        refundAmount,
        customerId,
        transactionDate: paymentDoc.data().initiatedAt,
      });

      if (!refundResult.success) {
        await db.collection("refunds").doc(orderId).set({
          orderId, userId, status: "FAILED",
          refundAmount, error: refundResult.error,
          requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        return res.status(400).json(refundResult);
      }

      // Save successful refund record
      await db.collection("refunds").doc(orderId).set({
        orderId, userId, status: "INITIATED",
        refundAmount, customerId,
        iciciResponse: refundResult.data,
        requestedAt:   admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Update the original payment record
      await db.collection("payments").doc(orderId).update({
        refundStatus:      "INITIATED",
        refundAmount,
        refundRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update nested transaction if metadata exists
      const { tenantId, appId } = paymentDoc.data();
      if (tenantId && appId) {
        const nestedPath = `${tenantId}/${appId}/payment_transactions/${orderId}`;
        await db.doc(nestedPath).update({
          refundStatus:      "INITIATED",
          refundAmount,
          refundRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(err => console.error(`${TAG} Failed to update nested transaction for refund:`, err.message));
      }

      console.log(`${TAG} ✅ Refund initiated | orderId=${orderId}`);
      return res.status(200).json({
        success:      true,
        orderId,
        refundAmount,
        message:      "Refund initiated successfully",
        status:       "0",
      });

    } catch (error) {
      console.error(`${TAG} Error:`, error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. Payment Callback (Webhook)
//    ICICI calls this URL after the user completes payment in the hosted page.
//    Configure this URL in ICICI Dashboard → Settings → API Configuration.
//    URL: https://paymentcallback-ltjv3mr7da-uc.a.run.app
// ─────────────────────────────────────────────────────────────────────────────
exports.paymentCallback = onRequest(
  {
    cors:           true,
    timeoutSeconds: 30,
    memory:         "256MiB",
  },
  async (req, res) => {
    const TAG = "[paymentCallback]";

    console.log(`${TAG} Callback received from ICICI`);

    try {
      const data = req.body;

      // Verify ICICI signature
      const providedHash = data.RESPONSE_HASH;
      const isValid      = iciciService.verifyResponseSignature(data, providedHash);

      if (!isValid) {
        console.error(`${TAG} Signature verification FAILED`);
        return res.status(400).json({ success: false, error: "Invalid signature" });
      }

      const orderId      = data.ORDER_ID;
      const responseCode = data.RESPONSE_CODE;
      const txnId        = data.TXN_ID;

      console.log(`${TAG} Processing callback for orderId=${orderId} | responseCode=${responseCode}`);

      // 1. Fetch metadata and current status from root payments collection
      const paymentDoc = await db.collection("payments").doc(orderId).get();
      if (!paymentDoc.exists) {
        console.error(`${TAG} CRITICAL: No payment record found in root collection for orderId=${orderId}`);
        return res.status(404).json({ success: false, error: "Payment record not found" });
      }

      const paymentData = paymentDoc.data();
      const { tenantId, appId, status: currentStatus } = paymentData;

      // 2. Prevent duplicate processing
      if (currentStatus === "SUCCESS") {
        console.log(`${TAG} Transaction ${orderId} already processed as SUCCESS. Skipping.`);
        return res.status(200).json({ success: true, message: "Already processed" });
      }

      // 3. SERVER-SIDE VERIFICATION (Mandatory for production)
      // Call ICICI Status Query API to confirm the transaction status independently
      console.log(`${TAG} Verifying transaction ${orderId} via ICICI Command API...`);
      const verificationResult = await iciciService.processCommand({
        orderId: orderId,
        command: "STATUS_QUERY",
      });

      console.log(`${TAG} Verification response:`, JSON.stringify(verificationResult, null, 2));

      let paymentStatus = "FAILED";
      const iciciVerifiedCode = verificationResult.success && verificationResult.data ? 
                               (verificationResult.data.RESPONSE_CODE || verificationResult.data.responseCode) : null;

      if (iciciVerifiedCode === "0" || iciciVerifiedCode === "00") {
        paymentStatus = "SUCCESS";
        console.log(`${TAG} ✅ Transaction verified successfully via Status API`);
      } else {
        console.warn(`${TAG} ⚠ Verification failed or returned non-zero code: ${iciciVerifiedCode}. Falling back to callback response code.`);
        // Fallback to callback data if status API is inconclusive but callback says success
        if (responseCode === "0" || responseCode === "00" || responseCode === "P1000") {
          paymentStatus = "SUCCESS";
        }
      }

      const updateData = {
        status:       paymentStatus,
        transactionId: txnId || data.TXN_ID || null,
        responseCode,
        callbackData:  data,
        verificationData: verificationResult.data || null,
        completedAt:   admin.firestore.FieldValue.serverTimestamp(),
        updatedAt:     admin.firestore.FieldValue.serverTimestamp(),
      };

      // 4. Update root payments collection
      await db.collection("payments").doc(orderId).update(updateData);

      // 5. Update nested payment_transactions collection (for multi-tenant success triggers)
      if (tenantId && appId) {
        const nestedPath = `${tenantId}/${appId}/payment_transactions/${orderId}`;
        console.log(`${TAG} Updating nested transaction at: ${nestedPath}`);
        
        await db.doc(nestedPath).update({
          status:       paymentStatus,
          paymentId:    txnId || data.TXN_ID || null,
          responseCode,
          updatedAt:    admin.firestore.FieldValue.serverTimestamp(),
        }).catch(err => {
          console.error(`${TAG} Failed to update nested transaction:`, err.message);
        });
      }

      console.log(`${TAG} ✅ Firestore updated for orderId=${orderId} | finalStatus=${paymentStatus}`);
      return res.status(200).json({ success: true, message: "Callback processed" });

    } catch (error) {
      console.error(`${TAG} Error:`, error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
  }
);

module.exports = {
  processRefund:   exports.processRefund,
  paymentCallback: exports.paymentCallback,
};
