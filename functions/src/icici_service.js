/**
 * Unified ICICI Payment Gateway Service (v2)
 * Handles Initiation, Status Query, and Webhook Signature Verification.
 * 
 * Uses SHA-512 hashing with the 32-character "clean" Merchant Key.
 */

"use strict";

const crypto = require("crypto");
const axios = require("axios");

class ICICIService {
    constructor() {
        this.merchantId = process.env.ICICI_MERCHANT_MID;
        this.aggregatorId = process.env.ICICI_AGGREGATOR_ID;
        this.terminalId = process.env.ICICI_TERMINAL_ID || "0001";
        this.merchantKey = process.env.ICICI_MERCHANT_KEY;
        this.merchantName = process.env.MERCHANT_NAME || "ROOKS AND BROOKS TECHNOLOGIES PRIVATE LIMITED";
        this.returnUrl = process.env.MERCHANT_RETURN_URL || process.env.ICICI_RETURN_URL;
        this.notifyUrl = process.env.MERCHANT_NOTIFICATION_URL || this.returnUrl;
        console.log(`[ICICI-INIT] Environment Check | MID: ${this.merchantId} | AGG: ${this.aggregatorId}`);
        console.log(`[ICICI-INIT] Loading ICICI Service. BaseURL: ${process.env.ICICI_BASE_URL}`);
        this.baseUrl = (process.env.ICICI_BASE_URL || "https://pgpay.icicibank.com").replace(/\/$/, "");
        
        // Endpoints — read directly from env so UAT/LIVE switch is a single .env change
        this.initiateUrl = process.env.ICICI_INITIATE_SALE_URL || `${this.baseUrl}/pg/api/v2/initiateSale`;
        this.commandUrl  = process.env.ICICI_COMMAND_URL        || `${this.baseUrl}/pg/api/command`;
    }

    /** 
     * Use the raw merchant key (with dashes).
     * This is required for most ICICI SHA-256 terminals.
     */
    get _activeKey() {
        return (this.merchantKey || "");
    }



    /** Format: DD-MM-YYYY HH:MM:SS */
    _getCurrentTimestamp() {
        const d = new Date();
        const pad = (n) => String(n).padStart(2, "0");
        return `${pad(d.getDate())}-${pad(d.getMonth() + 1)}-${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    }

    /**
     * REQUEST_HASH = SHA-512(MID|ORDER_ID|TXN_AMOUNT|AGGREGATOR_ID|CUST_ID|MOBILE_NO|EMAIL_ID|KEY)
     */
    _generateInitiateHash(payload) {
        const raw = [
            payload.MID,
            payload.ORDER_ID,
            payload.TXN_AMOUNT,
            payload.AGGREGATOR_ID,
            payload.CUST_ID,
            payload.MOBILE_NO,
            payload.EMAIL_ID,
            this._activeKey
        ].join("|");
        
        const hash = crypto.createHash("sha512").update(raw, "utf8").digest("hex").toLowerCase();
        return { hash, rawMasked: raw.replace(this._activeKey, "****") };
    }

    /**
     * COMMAND_HASH = SHA-512(MID|ORDER_ID|COMMAND|KEY)
     */
    _generateCommandHash(payload) {
        const raw = [
            payload.MID,
            payload.ORDER_ID,
            payload.COMMAND,
            this._activeKey
        ].join("|");
        
        const hash = crypto.createHash("sha512").update(raw, "utf8").digest("hex").toLowerCase();
        return { hash, rawMasked: raw.replace(this._activeKey, "****") };
    }

    /**
     * RESPONSE_HASH = SHA-512(ORDER_ID|TXN_AMOUNT|TXN_ID|RESPONSE_CODE|KEY)
     */
    verifyResponseSignature(data, providedHash) {
        try {
            const raw = [
                data.ORDER_ID,
                data.TXN_AMOUNT,
                data.TXN_ID || "",
                data.RESPONSE_CODE,
                this._activeKey
            ].join("|");


            const calculated = crypto.createHash("sha512").update(raw, "utf8").digest("hex").toLowerCase();
            const normalized = (providedHash || "").toLowerCase();

            console.log(`[ICICI-SVC] VERIFY | Calculated: ${calculated.substring(0, 10)}... | Provided: ${normalized.substring(0, 10)}...`);
            return calculated === normalized;
        } catch (e) {
            console.error("[ICICI-SVC] Signature verification error:", e.message);
            return false;
        }
    }

    /**
     * Initiate Sale (Card, Net Banking, or UPI WebView)
     */
    async initiateSale({ txnId, amount, paymentMode, email, mobile, userId }) {
        const TAG = `[ICICI-SALE][${txnId}]`;
        const amountStr = parseFloat(amount).toFixed(2);
        const mobile10 = (mobile || "9999999999").toString().replace(/[^0-9]/g, "").slice(-10);
        
        const payload = {
            merchantId: this.merchantId,
            aggregatorID: this.aggregatorId,
            merchantTxnNo: txnId,
            amount: amountStr,
            currency: "INR",
            txnDate: this._getCurrentTimestamp(),
            returnURL: this.returnUrl,
            notifyURL: this.notifyUrl,
            merchantName: this.merchantName.substring(0, 40),
            paymentMode: paymentMode.toUpperCase(),

            custId: (userId || txnId).toString().replace(/[^a-zA-Z0-9]/g, "").substring(0, 20),
            mobileNo: mobile10,
            emailId: email || "customer@example.com"
        };

        // ICICI Tilde sequence: MID~ORDER_ID~AMOUNT~AGG_ID~CUST_ID~MOBILE~EMAIL~KEY
        const raw = [
            payload.merchantId,
            payload.merchantTxnNo,
            payload.amount,
            payload.aggregatorID,
            payload.custId,
            payload.mobileNo,
            payload.emailId,
            this._activeKey
        ].join("~");




        const hash = crypto.createHash("sha256").update(raw, "utf8").digest("hex").toLowerCase();
        payload.secureHash = hash;


        console.log(`${TAG} Hashing string (masked): ${raw.replace(this._activeKey, "****")}`);
        console.log(`${TAG} Full Request Payload:`, JSON.stringify(payload, (k, v) => k === "secureHash" ? "****" : v));

        try {

            // Switching back to JSON as these specific camelCase keys are for the JSON API
            const response = await axios.post(this.initiateUrl, payload, { timeout: 20000 });
            const data = response.data;

            
            const responseCode = data.responseCode || data.RESPONSE_CODE;
            const success = responseCode === "0" || responseCode === "SUCCESS" || responseCode === "00";
            
            if (!success) {
                const detailedError = `ICICI Code: ${responseCode} | Msg: ${data.responseDescription || data.RESPONSE_MESSAGE || "No message"} | Full: ${JSON.stringify(data)}`;
                console.error(`${TAG} Sale Initiation Failed:`, detailedError);
                return { success: false, txnId: txnId, error: detailedError, raw: data };
            }

            return {
                success: true,
                redirectUrl: data.paymentUrl || data.REDIRECT_URL || data.PAYMENT_URL || data.redirectUrl || null,
                txnId: txnId,
                raw: data
            };

        } catch (e) {
            console.error(`${TAG} API Error:`, e.message);
            throw e;
        }
    }

    /**
     * ICICI UPI QR / Intent API (V2 Documentation Implementation)
     * Returns a upi://pay link for direct app navigation.
     */
    /**
     * ICICI UPI QR / Intent API (V2 Documentation Implementation)
     * Returns a upi://pay link for direct app navigation.
     */
    async generateUpiQr(txnId, amount, userId, mobile, email) {
        const TAG = `[ICICI-QR][${txnId}]`;
        const startTime = Date.now();
        console.log(`${TAG} [STEP 1] Start generateUpiQr execution at ${new Date().toISOString()}`);
        
        try {
            // --- Connectivity Diagnostics ---
            console.log(`${TAG} [DIAG] Running connectivity tests...`);
            try {
                const dns = require('dns').promises;
                const iciciHost = new URL(this.baseUrl).hostname;
                console.log(`${TAG} [DIAG] Resolving ${iciciHost}...`);
                const addr = await dns.resolve4(iciciHost).catch(e => `DNS_FAIL: ${e.message}`);
                console.log(`${TAG} [DIAG] DNS Result: ${JSON.stringify(addr)}`);
                
                console.log(`${TAG} [DIAG] Testing outbound to google.com...`);
                await axios.get("https://www.google.com", { timeout: 5000 })
                    .then(() => console.log(`${TAG} [DIAG] Google: SUCCESS`))
                    .catch(e => console.log(`${TAG} [DIAG] Google: FAIL (${e.message})`));

                console.log(`${TAG} [DIAG] Testing outbound to ICICI Base...`);
                await axios.get(this.baseUrl, { timeout: 5000 })
                    .then(() => console.log(`${TAG} [DIAG] ICICI Base: SUCCESS`))
                    .catch(e => console.log(`${TAG} [DIAG] ICICI Base: FAIL (${e.message})`));
            } catch (diagErr) {
                console.log(`${TAG} [DIAG] Critical failure in diagnostics: ${diagErr.message}`);
            }
            // -------------------------------

            console.log(`${TAG} [STEP 2] Preparing payload...`);
            let aggId = (this.aggregatorId || "").toString().trim();
            if (aggId && !aggId.startsWith("A")) aggId = "A" + aggId;

            const payload = {
                amount: Number(amount).toString().trim(),
                currency: "356",
                emailID: (email || "customer@example.com").trim(),
                merchantId: (this.merchantId || "").toString().trim(),
                aggregatorID: aggId,
                merchantRefNo: (txnId || "").toString().trim(),
                requestType: "UPIQR"
            };

            const sortedKeys = Object.keys(payload).sort();
            const plainText = sortedKeys.map(key => payload[key]).join("");
            const secureHash = crypto.createHmac("sha256", this._activeKey).update(plainText).digest("hex").toLowerCase();
            payload.secureHash = secureHash;

            const params = new URLSearchParams();
            for (const key in payload) params.append(key, payload[key]);
            const formBody = params.toString();
            const qrUrl = `${this.baseUrl}/tsp/pg/api/generateQR`;
            
            console.log(`${TAG} [STEP 6] Initiating hard-timeout Axios call to: ${qrUrl}`);
            
            const axiosConfig = {
                method: 'post',
                url: qrUrl,
                data: formBody,
                timeout: 30000,
                headers: { 
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ICICI-Backend/1.0"
                }
            };

            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error("MANUAL_AXIOS_TIMEOUT")), 35000)
            );

            console.log(`${TAG} [STEP 7] Entering Promise.race...`);
            const response = await Promise.race([
                axios(axiosConfig),
                timeoutPromise
            ]);

            const lastResponse = response.data;
            console.log(`${TAG} [STEP 8] Response received. Status: ${response.status}`);
            
            const returnCode = lastResponse.respHeader?.returnCode;
            const success = returnCode === 200 || returnCode === "200" || returnCode === 0 || returnCode === "0";

            return {
                success,
                txnId: txnId,
                upiUrl: lastResponse.respBody?.upiQR,
                error: success ? null : (lastResponse.respHeader?.desc || "ICICI Error"),
                raw: lastResponse
            };

        } catch (apiErr) {
            console.error(`${TAG} [ERROR] Execution failed: ${apiErr.message}`);
            if (apiErr.response) {
                console.error(`${TAG} SERVER ERROR | Status: ${apiErr.response.status} | Data:`, JSON.stringify(apiErr.response.data));
            } else if (apiErr.request) {
                console.error(`${TAG} NO_RESPONSE | Request sent but no response received. Check IP whitelisting.`);
            }
            return { 
                success: false, 
                txnId: txnId, 
                error: `ICICI Gateway Timeout or Error: ${apiErr.message}`,
                isNetworkError: !apiErr.response
            };
        } finally {
            console.log(`${TAG} [END] Duration: ${Date.now() - startTime}ms`);
        }
    }



    /**
     * Process Command (STATUS_QUERY or REFUND_REQUEST)
     */
    async processCommand({ orderId, command, transactionId, refundAmount, customerId, transactionDate }) {
        const TAG = `[ICICI-CMD][${command}][${orderId}]`;
        
        const payload = {
            MID: this.merchantId,
            AGGREGATOR_ID: this.aggregatorId,
            ORDER_ID: orderId,
            TXN_ID: transactionId || "",
            COMMAND: command,
            REF_ID: orderId, // For refund/status, usually orderId works as reference
            REF_AMOUNT: refundAmount ? parseFloat(refundAmount).toFixed(2) : "",
            TXN_DATE: transactionDate || this._getCurrentTimestamp(),
            CUST_ID: customerId || ""
        };

        const { hash, rawMasked } = this._generateCommandHash(payload);
        payload.COMMAND_HASH = hash;

        console.log(`${TAG} Hashing string (masked): ${rawMasked}`);

        try {
            const response = await axios.post(this.commandUrl, payload, { timeout: 20000 });
            const data = response.data;
            
            const responseCode = data.RESPONSE_CODE || data.responseCode;
            const success = responseCode === "0" || responseCode === "00";
            
            return {
                success,
                data,
                error: success ? null : (data.ERROR || data.RESPONSE_MESSAGE || `ICICI Code: ${responseCode}`)
            };
        } catch (e) {
            console.error(`${TAG} API Error:`, e.message);
            return { success: false, error: e.message };
        }
    }
}

module.exports = new ICICIService();
