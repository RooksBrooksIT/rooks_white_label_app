# ICICI Payment Gateway - Request/Response Reference

## API Request/Response Examples

---

## 1. InitiateSale API

### 1.1 Request from Firebase Function → ICICI

**Endpoint:** `https://pgpay.icicibank.com/pg/api/v2/initiateSale`

**Method:** POST

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "MID": "100000000429484",
  "AGGREGATOR_ID": "100000000429483",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "TXN_AMOUNT": "499.00",
  "CUST_ID": "user_firebase_uid",
  "MOBILE_NO": "9900433466",
  "EMAIL_ID": "dominicsaviod@gmail.com",
  "TXN_DATE": "04-05-2026 15:30:45",
  "RETURN_URL": "https://yourdomain.com/payment-callback",
  "NOTIFICATION_URL": "https://us-central1-your-project.cloudfunctions.net/paymentCallback",
  "MERCHANT_NAME": "M/S.ROOKS AND BROOKS TECHNOLOGIES PRIVATE LIMITED",
  "PRODUCT_DESC": "3-Month Premium Subscription",
  "PROMO_CODE": "",
  "TXNTYPE": "SALE",
  "REQUEST_HASH": "sha512_hash_generated_from_merchant_key"
}
```

**REQUEST_HASH Calculation:**
```
String to Hash = MID | TXN_AMOUNT | ORDER_ID | CUST_ID | MOBILE_NO | EMAIL_ID | MERCHANT_KEY

Example:
= 100000000429484 | 499.00 | ORDER_1714821234567_A1B2C3D4 | user_uid | 9900433466 | dominicsaviod@gmail.com | merchant_key_from_icici

SHA512(above string) = REQUEST_HASH
```

### 1.2 Response from ICICI

**Success Response (200):**
```json
{
  "RESPONSE_CODE": "0",
  "RESPONSE_MESSAGE": "Payment Initiated Successfully",
  "TXN_ID": "2026050400123456",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "REDIRECT_URL": "https://pgpay.icicibank.com/pg/pay?key=abc123xyz789",
  "TIMESTAMP": "04-05-2026 15:30:50"
}
```

**Error Response (400):**
```json
{
  "RESPONSE_CODE": "1",
  "RESPONSE_MESSAGE": "Invalid Request",
  "ERROR": "Missing required field: MID",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4"
}
```

### 1.3 What Firebase Function Returns to Flutter

```json
{
  "success": true,
  "orderId": "ORDER_1714821234567_A1B2C3D4",
  "amount": 499.00,
  "message": "Payment initiated successfully",
  "redirectUrl": "https://pgpay.icicibank.com/pg/pay?key=abc123xyz789"
}
```

---

## 2. CheckPaymentStatus / Refund API (Command)

### 2.1 Status Query Request

**Endpoint:** `https://pgpay.icicibank.com/pg/api/command`

**Method:** POST

**For Status Check:**
```json
{
  "MID": "100000000429484",
  "AGGREGATOR_ID": "100000000429483",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "TXN_ID": "2026050400123456",
  "COMMAND": "STATUS_QUERY",
  "REF_ID": "",
  "REF_AMOUNT": "",
  "TXN_DATE": "04-05-2026 15:30:45",
  "CUST_ID": "user_firebase_uid",
  "COMMAND_HASH": "sha512_hash"
}
```

**For Refund:**
```json
{
  "MID": "100000000429484",
  "AGGREGATOR_ID": "100000000429483",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "TXN_ID": "2026050400123456",
  "COMMAND": "REFUND_REQUEST",
  "REF_ID": "REF_1714821500000",
  "REF_AMOUNT": "499.00",
  "TXN_DATE": "04-05-2026 15:30:45",
  "CUST_ID": "user_firebase_uid",
  "COMMAND_HASH": "sha512_hash"
}
```

**COMMAND_HASH Calculation:**
```
String to Hash = MID | ORDER_ID | COMMAND | MERCHANT_KEY

For Status:
= 100000000429484 | ORDER_1714821234567_A1B2C3D4 | STATUS_QUERY | merchant_key

For Refund:
= 100000000429484 | ORDER_1714821234567_A1B2C3D4 | REFUND_REQUEST | merchant_key

SHA512(above string) = COMMAND_HASH
```

### 2.2 Status Check Response

**Success (Payment Successful):**
```json
{
  "RESPONSE_CODE": "0",
  "RESPONSE_MESSAGE": "Transaction successful",
  "TXN_ID": "2026050400123456",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "TXN_AMOUNT": "499.00",
  "TXN_DATE": "04-05-2026 15:35:22",
  "AUTH_CODE": "123456",
  "RESPONSE_CODE_DESC": "Approved"
}
```

**Success (Payment Failed):**
```json
{
  "RESPONSE_CODE": "1",
  "RESPONSE_MESSAGE": "Transaction failed",
  "TXN_ID": "2026050400123456",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "RESPONSE_CODE_DESC": "Declined"
}
```

### 2.3 Refund Response

**Success:**
```json
{
  "RESPONSE_CODE": "0",
  "RESPONSE_MESSAGE": "Refund Initiated",
  "REF_ID": "REF_1714821500000",
  "TXN_ID": "2026050400123456",
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "REF_AMOUNT": "499.00",
  "REF_STATUS": "INITIATED"
}
```

---

## 3. Firebase Function Responses to Flutter

### 3.1 initiatePayment() Response

**Success:**
```json
{
  "success": true,
  "orderId": "ORDER_1714821234567_A1B2C3D4",
  "amount": 499.00,
  "transactionId": "2026050400123456",
  "redirectUrl": "https://pgpay.icicibank.com/pg/pay?key=abc123xyz789",
  "message": "Payment initiated successfully"
}
```

**Failure:**
```json
{
  "success": false,
  "error": "Invalid mobile number format",
  "message": "Failed to initiate payment"
}
```

### 3.2 checkPaymentStatus() Response

**Success:**
```json
{
  "success": true,
  "orderId": "ORDER_1714821234567_A1B2C3D4",
  "status": "SUCCESS",
  "amount": 499.00,
  "transactionId": "2026050400123456"
}
```

**Pending:**
```json
{
  "success": true,
  "orderId": "ORDER_1714821234567_A1B2C3D4",
  "status": "PENDING",
  "amount": 499.00,
  "transactionId": null
}
```

### 3.3 processRefund() Response

**Success:**
```json
{
  "success": true,
  "orderId": "ORDER_1714821234567_A1B2C3D4",
  "refundAmount": 499.00,
  "message": "Refund initiated successfully"
}
```

**Failure:**
```json
{
  "success": false,
  "error": "Payment not found or not completed",
  "message": "Failed to process refund"
}
```

---

## 4. Callback Webhook from ICICI

### 4.1 Callback Request to Your Function

**When:** After user completes payment in ICICI gateway

**To:** `https://us-central1-your-project.cloudfunctions.net/paymentCallback`

**Method:** POST

**Body:**
```json
{
  "ORDER_ID": "ORDER_1714821234567_A1B2C3D4",
  "TXN_ID": "2026050400123456",
  "TXN_AMOUNT": "499.00",
  "RESPONSE_CODE": "0",
  "RESPONSE_MESSAGE": "Transaction Successful",
  "TXN_DATE": "04-05-2026 15:35:22",
  "AUTH_CODE": "123456",
  "RESPONSE_HASH": "sha512_hash_for_verification"
}
```

### 4.2 Callback Verification

**Backend verifies:**
```
ReceivedHash = REQUEST_HASH from callback
CalculatedHash = SHA512(ORDER_ID | TXN_AMOUNT | TXN_ID | RESPONSE_CODE | MERCHANT_KEY)

If ReceivedHash == CalculatedHash → Trust the callback
Else → Reject it (potential tampered data)
```

### 4.3 Your Function Responds

```json
{
  "success": true,
  "message": "Callback processed successfully"
}
```

---

## 5. Complete Payment Flow Diagram

```
┌─────────────────┐
│  Flutter App    │
└────────┬────────┘
         │
         │ 1. User clicks "Pay ₹499"
         │    Call initiatePayment()
         │
         ▼
┌─────────────────────────────────────────┐
│  Firebase Cloud Function                 │
│  initiatePayment()                       │
│  ├─ Validate user auth                  │
│  ├─ Validate payment data                │
│  ├─ Generate hash with MERCHANT_KEY      │
│  └─ Call ICICI API                       │
└────────┬────────────────────────────────┘
         │
         │ 2. Call InitiateSale API
         │    + REQUEST_HASH (signed)
         │    + All payment details
         │
         ▼
┌─────────────────────────────────────┐
│  ICICI Orange Payment Gateway       │
│  /pg/api/v2/initiateSale            │
│  ├─ Verify hash                     │
│  ├─ Create transaction               │
│  └─ Return redirect URL              │
└────────┬────────────────────────────┘
         │
         │ 3. Return: TXN_ID + REDIRECT_URL
         │
         ▼
┌─────────────────────────────────────┐
│  Firebase Function                   │
│  ├─ Save to Firestore               │
│  │  (status: INITIATED)              │
│  └─ Return to Flutter                │
└────────┬────────────────────────────┘
         │
         │ 4. Return: redirectUrl
         │
         ▼
┌─────────────────────────────────┐
│  Flutter App                     │
│  ├─ Open WebView                 │
│  └─ Redirect to ICICI URL       │
└────────┬────────────────────────┘
         │
         │ 5. User enters card details
         │    User confirms payment
         │
         ▼
┌──────────────────────────────────┐
│  ICICI Payment Gateway           │
│  ├─ Process payment              │
│  ├─ Call your webhook callback   │
│  └─ Redirect to success URL      │
└────────┬─────────────────────────┘
         │
         │ 6. Callback webhook:
         │    POST /paymentCallback
         │    + ORDER_ID
         │    + TXN_ID
         │    + RESPONSE_CODE (0=success, 1=fail)
         │    + RESPONSE_HASH (signature)
         │
         ▼
┌──────────────────────────────────────┐
│  Firebase Cloud Function              │
│  paymentCallback()                    │
│  ├─ Verify RESPONSE_HASH              │
│  ├─ Update Firestore (status: SUCCESS)│
│  ├─ Send FCM notification             │
│  └─ Activate subscription             │
└──────────────────────────────────────┘
         │
         │ 7. FCM Notification to user
         │
         ▼
┌─────────────────────────┐
│  Flutter App            │
│  Show "Payment Success" │
│  Update UI              │
└─────────────────────────┘
```

---

## 6. Firestore Data Structure

### 6.1 Payments Collection

```
payments/
├── ORDER_1714821234567_A1B2C3D4/
│   ├── orderId: "ORDER_1714821234567_A1B2C3D4"
│   ├── userId: "firebase_user_uid"
│   ├── status: "SUCCESS" (INITIATED, SUCCESS, FAILED, PENDING)
│   ├── amount: 499.00
│   ├── customerId: "user_uid"
│   ├── mobileNumber: "9900433466"
│   ├── emailId: "dominicsaviod@gmail.com"
│   ├── productDescription: "3-Month Premium Subscription"
│   ├── transactionId: "2026050400123456"
│   ├── responseCode: "0"
│   ├── initiatedAt: Timestamp(2026-05-04 15:30:45)
│   ├── completedAt: Timestamp(2026-05-04 15:35:22)
│   ├── iciciResponse: { ... full response object ... }
│   └── callbackData: { ... callback details ... }
```

### 6.2 Refunds Collection

```
refunds/
├── ORDER_1714821234567_A1B2C3D4/
│   ├── orderId: "ORDER_1714821234567_A1B2C3D4"
│   ├── userId: "firebase_user_uid"
│   ├── status: "INITIATED" (INITIATED, SUCCESS, FAILED)
│   ├── refundAmount: 499.00
│   ├── customerId: "user_uid"
│   ├── requestedAt: Timestamp(2026-05-04 16:00:00)
│   ├── iciciResponse: { ... }
│   └── notes: "User requested refund"
```

---

## 7. Error Codes Reference

### ICICI Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Mark payment as SUCCESS |
| 1 | Failed | Mark payment as FAILED |
| 2 | Pending | Wait for callback |
| 3 | Cancelled | User cancelled |
| 4 | Invalid | Invalid request |
| 5 | Timeout | Retry later |

### Firebase Function Error Codes

| Code | HTTP Status | Meaning |
|------|------------|---------|
| Missing required field | 400 | Validation failed |
| Unauthorized | 401 | No auth token |
| Invalid amount | 400 | Amount out of range |
| Order not found | 404 | No such order |
| Method not allowed | 405 | Wrong HTTP method |
| Too many requests | 429 | Rate limit exceeded |
| Internal server error | 500 | Backend issue |

---

## 8. Testing with Curl

### Test InitiateSale

```bash
curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/initiatePayment \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "ORDER_TEST_123456",
    "amount": 1.00,
    "customerId": "test_user",
    "mobileNumber": "9900433466",
    "emailId": "test@example.com",
    "productDescription": "Test Payment"
  }'
```

### Test Status Check

```bash
curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/checkPaymentStatus \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "ORDER_TEST_123456",
    "customerId": "test_user"
  }'
```

### Get Your ID Token

```bash
# In Flutter
final user = FirebaseAuth.instance.currentUser;
final token = await user?.getIdToken();
print(token);
```

---

## 9. Field Validation Rules

| Field | Type | Length | Format | Example |
|-------|------|--------|--------|---------|
| ORDER_ID | String | 10-50 | `ORDER_[0-9A-Z_-]+` | ORDER_1714821234567_A1B2C3D4 |
| TXN_AMOUNT | Decimal | - | 2 decimals | 499.00 |
| CUST_ID | String | 1-50 | Alphanumeric | user_firebase_uid |
| MOBILE_NO | String | 10 | Starts 6-9 | 9900433466 |
| EMAIL_ID | String | - | Valid email | dominicsaviod@gmail.com |
| MID | String | - | Exact match | 100000000429484 |

---

**For more details, contact: msintegration@icici.bank.in**
