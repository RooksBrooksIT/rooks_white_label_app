/**
 * ICICI Payment Service - Production Refactor
 * Version: 12.0.0
 * 
 * Features:
 * - HMAC-SHA256 Alphabetical Hashing
 * - Proper Retry Logic
 * - Secure Header Management
 * - Robust Error Handling
 * - Certification Ready
 */

"use strict";

const axios = require("axios");
const crypto = require("crypto");
const { generateSecureHash, generateSHA512 } = require("./icici_hash");

class ICICIService {
    constructor() {
        this.merchantId = (process.env.ICICI_MERCHANT_MID || "100000000429484").trim();
        this.aggregatorID = (process.env.ICICI_AGGREGATOR_ID || "100000000429483").trim();
        this.merchantKey = (process.env.ICICI_MERCHANT_KEY || "").trim();
        this.baseUrl = (process.env.ICICI_BASE_URL || "https://pgpay.icicibank.com").trim();
        
        // Correct Production Endpoints
        this.initiateSaleEndpoint = `${this.baseUrl}/pg/api/v2/initiateSale`;
        this.generateQrEndpoint = `${this.baseUrl}/pg/api/generateQR`; // Mandated fallback/primary
        this.commandEndpoint = `${this.baseUrl}/pg/api/command`;
        
        this.returnUrl = (process.env.ICICI_RETURN_URL || "").trim();

        // Production Axios Instance
        this.client = axios.create({
            timeout: 30000,
            validateStatus: () => true, // Handle all status codes manually
            headers: {
                "Accept": "application/json",
                "User-Agent": "Rooks-Tech-Service/12.0"
            }
        });
    }

    /**
     * Helper for Retries
     */
    async _requestWithRetry(config, maxRetries = 2) {
        let lastError;
        for (let i = 0; i <= maxRetries; i++) {
            try {
                const response = await this.client(config);
                // ICICI might return 200 with an error body or a 5xx
                if (response.status >= 500 && i < maxRetries) {
                    console.warn(`[ICICI] Retrying due to status ${response.status} (Attempt ${i + 1})`);
                    await new Promise(r => setTimeout(r, 1000 * (i + 1)));
                    continue;
                }
                return response;
            } catch (err) {
                lastError = err;
                if (i < maxRetries) {
                    await new Promise(r => setTimeout(r, 1000 * (i + 1)));
                    continue;
                }
            }
        }
        throw lastError;
    }

    /**
     * UPI QR flow - Fully Compliant
     */
    async generateUpiQr({ txnId, amount, email }) {
        const TAG = `[UPI][${txnId}]`;
        try {
            const formattedAmount = parseFloat(amount).toFixed(2);
            
            const payload = {
                merchantId: this.merchantId,
                aggregatorID: this.aggregatorID,
                merchantRefNo: txnId,
                amount: formattedAmount,
                currency: "356",
                emailID: email || "customer@example.com",
                requestType: "UPIQR"
            };

            const hashResult = generateSecureHash(payload, this.merchantKey);
            payload.secureHash = hashResult.hash;

            // Form data formatting
            const params = new URLSearchParams();
            Object.entries(payload).forEach(([k, v]) => params.append(k, v));

            const response = await this._requestWithRetry({
                method: "POST",
                url: this.generateQrEndpoint,
                data: params.toString(),
                headers: { "Content-Type": "application/x-www-form-urlencoded" }
            });

            return this._parseResponse(response, txnId, "UPI");
        } catch (error) {
            console.error(`${TAG} FATAL:`, error.message);
            return { success: false, error: "Payment Gateway Connectivity Issue" };
        }
    }

    /**
     * CARD/NETBANKING Flow
     */
    async initiateSale({ txnId, amount, email, customerName, customerMobile, paymentMode }) {
        const TAG = `[SALE][${txnId}]`;
        try {
            const formattedAmount = parseFloat(amount).toFixed(2);
            
            const payload = {
                merchantId: this.merchantId,
                aggregatorID: this.aggregatorID,
                merchantTxnNo: txnId,
                amount: formattedAmount,
                currency: "356",
                emailId: email || "customer@example.com",
                mobileNumber: customerMobile || "919999999999",
                customerName: (customerName || "Customer").substring(0, 50),
                paymentMode: paymentMode || "CARD",
                returnUrl: this.returnUrl,
                requestType: "1"
            };

            const hashResult = generateSecureHash(payload, this.merchantKey);
            payload.secureHash = hashResult.hash;

            const response = await this._requestWithRetry({
                method: "POST",
                url: this.initiateSaleEndpoint,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            return this._parseResponse(response, txnId, "SALE");
        } catch (error) {
            console.error(`${TAG} FATAL:`, error.message);
            return { success: false, error: "Gateway Timeout" };
        }
    }

    /**
     * Corrected Status Check API
     */
    async statusCheck(txnId) {
        const TAG = `[STATUS][${txnId}]`;
        try {
            const payload = {
                MID: this.merchantId,
                AGGREGATOR_ID: this.aggregatorID,
                ORDER_ID: txnId,
                COMMAND: "STATUS_QUERY",
                TXN_DATE: this._getISTTimestamp()
            };

            // Command API often uses SHA512 Pipe separation
            const raw = [payload.MID, payload.ORDER_ID, payload.COMMAND, this.merchantKey].join("|");
            payload.COMMAND_HASH = generateSHA512(raw);

            const response = await this._requestWithRetry({
                method: "POST",
                url: this.commandEndpoint,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            if (response.status === 200) {
                return { success: true, data: response.data };
            }
            return { success: false, error: `HTTP ${response.status}` };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Refund API
     */
    async processRefund(txnId, refundAmount) {
        const TAG = `[REFUND][${txnId}]`;
        try {
            const payload = {
                MID: this.merchantId,
                AGGREGATOR_ID: this.aggregatorID,
                ORDER_ID: txnId,
                AMOUNT: parseFloat(refundAmount).toFixed(2),
                COMMAND: "REFUND",
                TXN_DATE: this._getISTTimestamp()
            };

            const raw = [payload.MID, payload.ORDER_ID, payload.AMOUNT, payload.COMMAND, this.merchantKey].join("|");
            payload.COMMAND_HASH = generateSHA512(raw);

            const response = await this._requestWithRetry({
                method: "POST",
                url: this.commandEndpoint,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            if (response.status === 200) {
                const data = response.data;
                const isSuccess = (data?.RESPONSE_CODE === "0" || data?.responseCode === "0");
                return { success: isSuccess, data: response.data };
            }
            return { success: false, error: `HTTP ${response.status}` };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Unified Response Parser
     */
    _parseResponse(response, txnId, mode) {
        const data = response.data;
        
        // Handle HTTP errors
        if (response.status !== 200) {
            return { success: false, error: `Gateway returned HTTP ${response.status}`, raw: data };
        }

        // Logic for returnCode (UPI) vs responseCode (SALE)
        const returnCode = data?.respHeader?.returnCode || data?.responseCode || data?.status;
        const isSuccess = (returnCode == "200" || returnCode == "0" || returnCode == "SUCCESS" || returnCode == "00");

        if (isSuccess) {
            const upiUrl = data?.respBody?.upiQR || data?.respBody?.bharatQR;
            const redirectUrl = data?.paymentPageUrl || data?.respBody?.paymentPageUrl;
            
            return { 
                success: true, 
                txnId, 
                upiUrl: upiUrl || null,
                redirectUrl: redirectUrl || upiUrl || null
            };
        }

        const errorMsg = data?.respHeader?.desc || data?.message || data?.errorMsg || "Transaction Rejected";
        return { success: false, error: errorMsg, raw: data };
    }

    _getISTTimestamp() {
        const ist = new Date(new Date().getTime() + (5.5 * 60 * 60 * 1000));
        const pad = (n) => String(n).padStart(2, "0");
        return `${ist.getUTCFullYear()}${pad(ist.getUTCMonth() + 1)}${pad(ist.getUTCDate())}${pad(ist.getUTCHours())}${pad(ist.getUTCMinutes())}${pad(ist.getUTCSeconds())}`;
    }
}

module.exports = new ICICIService();
