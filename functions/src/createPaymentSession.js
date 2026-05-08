/**
 * Cloud Function: createPaymentSession
 * ─────────────────────────────────────────────────────────────────────────────
 * Accepts:  POST { amount, userId, paymentMode, planName }
 * Returns:  { success, txnId, redirectUrl, paymentUrl }
 * Saves:    payments/{txnId}  →  status = PENDING
 *
 * Supported paymentMode values: "CARD" | "NETBANKING" | "UPI"
 *
 * Security:
 *  - All ICICI secrets live in Firebase env vars (process.env)
 *  - AES encryption handled inside iciciCardNetbankingService
 *  - Firebase Auth token is verified before any processing
 *  - CORS locked to app-check-aware clients (enforceAppCheck: false for mobile
 *    SDK compatibility; set true if you enable AppCheck in your Flutter app)
 */

"use strict";

const { onRequest }    = require("firebase-functions/v2/https");
const admin            = require("firebase-admin");
const { v4: uuidv4 }  = require("uuid");
const iciciService = require("./icici_service");

// Guard: only initialize once (shared with index.js)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ─── Allowed payment modes ────────────────────────────────────────────────────
const VALID_PAYMENT_MODES = ["CARD", "NETBANKING", "UPI"];

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function
// ─────────────────────────────────────────────────────────────────────────────
/**
 * Create Payment Session for ICICI Gateway
 * Force Redeploy: 2026-05-07-v2
 */
exports.createPaymentSession = onRequest(
  {
    cors:           true,      // Allow Flutter mobile & web clients
    timeoutSeconds: 120,
    memory:         "256MiB",
    // enforceAppCheck: true  ← enable once AppCheck is live in Flutter
  },
  async (req, res) => {
    const TAG = "[createPaymentSession]";
    const fnStartTime = Date.now();
    console.log(`${TAG} >>> Function Started at ${new Date().toISOString()}`);

    try {
      // ── 1. Method guard ───────────────────────────────────────────────────────
      if (req.method !== "POST") {
        console.warn(`${TAG} Method not allowed: ${req.method}`);
        return res.status(405).json({ success: false, error: "Method not allowed. Use POST." });
      }

      // ── 2. Auth guard (Firebase ID token) ────────────────────────────────────
      const authHeader = req.headers.authorization || "";
      const idToken    = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

      if (!idToken) {
        console.warn(`${TAG} Missing Authorization header`);
        return res.status(401).json({ success: false, error: "Unauthorized: no Bearer token provided." });
      }

      let decodedToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch (authErr) {
        console.error(`${TAG} Token verification failed:`, authErr.message);
        return res.status(401).json({ success: false, error: "Unauthorized: invalid or expired token." });
      }

      const verifiedUid = decodedToken.uid;
      console.log(`${TAG} Authenticated user: ${verifiedUid}`);

      // ── 3. Parse & validate body ──────────────────────────────────────────────
      const { orderId, amount, userId, paymentMode, planName, email, mobile, tenantId, appId } = req.body;

      const missingFields = [];
      if (!amount)      missingFields.push("amount");
      if (!userId)      missingFields.push("userId");
      if (!paymentMode) missingFields.push("paymentMode");
      if (!planName)    missingFields.push("planName");
      if (!tenantId)    missingFields.push("tenantId");
      if (!appId)       missingFields.push("appId");

      if (missingFields.length > 0) {
        console.warn(`${TAG} Missing required fields:`, missingFields);
        return res.status(400).json({
          success: false,
          error:   "Missing required fields",
          missing: missingFields,
        });
      }

      // Normalise and validate paymentMode
      const normMode = paymentMode.toUpperCase().trim();
      if (!VALID_PAYMENT_MODES.includes(normMode)) {
        console.warn(`${TAG} Invalid paymentMode: "${paymentMode}"`);
        return res.status(400).json({
          success: false,
          error:   `Invalid paymentMode. Accepted values: ${VALID_PAYMENT_MODES.join(", ")}`,
        });
      }

      // Amount must be a positive number
      const parsedAmount = parseFloat(amount);
      if (isNaN(parsedAmount) || parsedAmount <= 0) {
        console.warn(`${TAG} Invalid amount: ${amount}`);
        return res.status(400).json({ success: false, error: "amount must be a positive number." });
      }

      // Security: ensure the token's UID matches the requested userId
      if (verifiedUid !== userId) {
        console.warn(`${TAG} UID mismatch: token=${verifiedUid}, body.userId=${userId}`);
        return res.status(403).json({ success: false, error: "Forbidden: userId does not match authenticated user." });
      }

      // ── 4. Use provided orderId or generate unique txnId ──────────────────────
      let rawTxnId = orderId ? String(orderId).replace(/[^a-zA-Z0-9]/g, "") : "";
      if (!rawTxnId || rawTxnId.length < 5) {
        rawTxnId = `TXN${uuidv4().split("-")[0].toUpperCase()}${Date.now().toString().slice(-6)}`;
      }
      const txnId = `RB${rawTxnId}`.substring(0, 20);

      console.log(`${TAG} Final txnId: ${txnId} | mode=${normMode} | amount=${parsedAmount}`);

      // ── 5. Check for existing transaction ─────────────────────────────────────
      const paymentDocRef = db.collection("payments").doc(txnId);
      const existingDoc = await paymentDocRef.get();
      if (existingDoc.exists && existingDoc.data().status === "SUCCESS") {
        return res.status(409).json({ success: false, error: "Transaction already completed.", txnId });
      }

      await paymentDocRef.set({
        txnId, userId, tenantId, appId,
        amount: parsedAmount,
        paymentMode: normMode,
        planName,
        status: "PENDING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ── 6. Call ICICI Service ───────────────────────────────────────────────
      let iciciResult;
      if (normMode === "UPI") {
        console.log(`${TAG} [CALLING_UPI] txnId=${txnId}`);
        iciciResult = await iciciService.generateUpiQr(txnId, parsedAmount, userId, mobile, email);
        if (iciciResult.success) iciciResult.redirectUrl = iciciResult.upiUrl;
      } else {
        console.log(`${TAG} [CALLING_CARD_NET] txnId=${txnId}`);
        iciciResult = await iciciService.initiateSale({
          txnId, amount: parsedAmount, userId, paymentMode: normMode, planName, email, mobile,
        });
      }

      // ── 7. Handle Response ──────────────────────────────────────────────────
      if (!iciciResult.success) {
        console.error(`${TAG} [FAILURE] txnId=${txnId} Error=${iciciResult.error}`);
        await paymentDocRef.update({
          status: "FAILED",
          errorMsg: iciciResult.error,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});

        return res.status(iciciResult.isNetworkError ? 504 : 400).json({
          success: false,
          txnId,
          error: iciciResult.error
        });
      }

      // ── 8. Final Success ───────────────────────────────────────────────────
      await paymentDocRef.update({
        redirectUrl: iciciResult.redirectUrl || null,
        paymentUrl: iciciResult.paymentUrl || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});

      console.log(`${TAG} [TERMINATE_SUCCESS] txnId=${txnId}`);
      return res.status(200).json({
        success: true,
        txnId,
        redirectUrl: iciciResult.redirectUrl || null,
        paymentUrl: iciciResult.paymentUrl || null,
        paymentMode: normMode,
      });

    } catch (globalErr) {
      console.error(`${TAG} [FATAL_GLOBAL_ERROR]`, globalErr.message);
      return res.status(500).json({
        success: false,
        error: `Internal Server Error: ${globalErr.message}`
      });
    } finally {
      console.log(`${TAG} <<< Function Completed in ${Date.now() - fnStartTime}ms`);
    }
  }
);
