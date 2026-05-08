# ICICI Payment Gateway - LIVE Implementation Guide

## Overview
This guide covers the complete setup for ICICI Orange Payment Gateway LIVE integration using Firebase Cloud Functions as a secure backend.

**Your Credentials:**
- Merchant Name: M/S.ROOKS AND BROOKS TECHNOLOGIES PRIVATE LIMITED
- Merchant MID: 100000000429484
- Aggregator ID: 100000000429483
- Production URLs:
  - Base: https://pgpay.icicibank.com
  - InitiateSale: https://pgpay.icicibank.com/pg/api/v2/initiateSale
  - Command: https://pgpay.icicibank.com/pg/api/command
  - Dashboard: https://pgportal.icicibank.com/v2/pgmp/login

---

## Step 1: Store ICICI Keys Securely in Firebase

### Option A: Firebase Secret Manager (RECOMMENDED)

**Create secrets via Google Cloud Console:**

1. Go to: https://console.cloud.google.com/security/secret-manager
2. Create secrets:
   ```
   ICICI_MERCHANT_KEY
   ICICI_MERCHANT_MID
   ICICI_AGGREGATOR_ID
   ```

3. Grant Firebase Cloud Functions access:
   ```bash
   gcloud secrets add-iam-policy-binding ICICI_MERCHANT_KEY \
     --member=serviceAccount:your-project@appspot.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

**Access in Cloud Functions:**
```javascript
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

async function getSecret(secretName) {
  const client = new SecretManagerServiceClient();
  const projectId = process.env.GCLOUD_PROJECT;
  
  const name = client.secretVersionPath(projectId, secretName, 'latest');
  const [version] = await client.accessSecretVersion({ name });
  return version.payload.data.toString('utf8');
}
```

### Option B: Environment Variables (.env.local)

**File: functions/.env.local (NOT committed to git)**
```
ICICI_MERCHANT_MID=100000000429484
ICICI_MERCHANT_KEY=your_actual_merchant_key_from_icici_dashboard
ICICI_AGGREGATOR_ID=100000000429483
ICICI_BASE_URL=https://pgpay.icicibank.com
ICICI_INITIATE_SALE_URL=https://pgpay.icicibank.com/pg/api/v2/initiateSale
ICICI_COMMAND_URL=https://pgpay.icicibank.com/pg/api/command
NODE_ENV=production
```

**Add to .gitignore:**
```
functions/.env.local
functions/.env.*.local
```

**How to get your Merchant Key:**
1. Login to: https://pgportal.icicibank.com/v2/pgmp/login
2. Navigate to: Settings > Key Management
3. Generate or download your key
4. Copy to .env.local file

---

## Step 2: Update package.json Dependencies

**File: functions/package.json**

Add required packages:
```bash
npm install crypto https dotenv uuid
npm install --save-dev firebase-functions-test
```

Your dependencies should include:
```json
{
  "dependencies": {
    "firebase-admin": "^13.6.1",
    "firebase-functions": "^7.0.5",
    "crypto": "^1.0.1",
    "dotenv": "^16.4.5",
    "uuid": "^9.0.0"
  }
}
```

---

## Step 3: Deploy Firebase Functions

### Setup Process

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase:**
   ```bash
   firebase login
   ```

3. **Initialize Firebase in your project:**
   ```bash
   firebase init functions
   ```

4. **Copy files to functions/src/:**
   - `iciciPaymentService.js`
   - `iciciPaymentFunctions.js`

5. **Update functions/index.js:**
   Add at the end:
   ```javascript
   const paymentFunctions = require('./src/iciciPaymentFunctions');
   exports.initiatePayment = paymentFunctions.initiatePayment;
   exports.checkPaymentStatus = paymentFunctions.checkPaymentStatus;
   exports.processRefund = paymentFunctions.processRefund;
   exports.paymentCallback = paymentFunctions.paymentCallback;
   exports.testPaymentFlow = paymentFunctions.testPaymentFlow;
   ```

### Deploy to Firebase

```bash
# Deploy only functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:initiatePayment

# View logs
firebase functions:log

# Watch live logs
firebase functions:log --follow
```

### Verify Deployment

```bash
# List deployed functions
firebase functions:list

# Test a function locally
firebase emulators:start --only functions
```

---

## Step 4: Configure Flutter App

### 1. Update pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^25.0.0
  firebase_auth: ^4.15.0
  cloud_functions: ^4.10.0
  http: ^1.1.0
  uuid: ^4.0.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
```

Install:
```bash
flutter pub get
```

### 2. Initialize Firebase in main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

### 3. Add Payment Service

Copy `payment_service.dart` to `lib/services/`

### 4. Use in Your Subscription Screen

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'services/payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _paymentService = PaymentService();

  Future<void> _startPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final response = await _paymentService.initiatePayment(
      orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      amount: 499.00,
      customerId: user.uid,
      mobileNumber: user.phoneNumber ?? '9900433466',
      emailId: user.email ?? '',
      productDescription: '3-Month Premium Subscription',
    );

    if (response.success) {
      // Show payment success or open payment gateway
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Payment failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Premium Subscription')),
      body: Center(
        child: ElevatedButton(
          onPressed: _startPayment,
          child: Text('Pay ₹499 Now'),
        ),
      ),
    );
  }
}
```

---

## Step 5: Testing LIVE Integration

### Test 1: Use Small Amount (₹1)

**Test this FIRST before full integration:**

```dart
final response = await _paymentService.initiatePayment(
  orderId: 'TEST_ORDER_${DateTime.now().millisecondsSinceEpoch}',
  amount: 1.00, // Test amount
  customerId: user.uid,
  mobileNumber: '9900433466',
  emailId: 'dominicsaviod@gmail.com',
  productDescription: 'Test Payment',
);
```

### Test 2: Check Firestore Records

After payment, verify in Firebase Console:

```
firestore > payments collection
  - Document ID: ORDER_123456
    - status: SUCCESS/FAILED
    - amount: 1.00
    - transactionId: TXN_ID from ICICI
    - iciciResponse: Full response object
```

### Test 3: Verify Cloud Functions Logs

```bash
firebase functions:log

# Or in Firebase Console:
# Functions > logs tab
```

Look for:
```
[PAYMENT] Initiating sale for Order: ORDER_xxx, Amount: 1.00
[PAYMENT] Hash generated for Order: ORDER_xxx
[PAYMENT] InitiateSale error: ...
```

### Test 4: End-to-End Flow

1. **Initiate Payment:**
   - Call `initiatePayment()`
   - Verify in Firestore (status: INITIATED)

2. **User Completes Payment:**
   - User fills payment details in ICICI gateway
   - ICICI processes and redirects to callback URL

3. **Check Status:**
   - Call `checkPaymentStatus()`
   - Verify status updated in Firestore (status: SUCCESS)

4. **Verify Webhook:**
   - Check Firebase logs for callback receipt
   - Verify ICICI callback hash signature

---

## Step 6: Security Best Practices

### ✅ DO:
- ✅ Store merchant key in Secret Manager
- ✅ All API calls from backend (Firebase Functions)
- ✅ Verify Firebase Auth tokens in functions
- ✅ Verify ICICI response signatures
- ✅ Log all transactions (without sensitive data)
- ✅ Use HTTPS only
- ✅ Validate input amounts and formats
- ✅ Implement rate limiting

### ❌ DON'T:
- ❌ Expose merchant key in frontend code
- ❌ Call ICICI API directly from Flutter
- ❌ Store payment data in local device storage
- ❌ Log merchant key or transaction IDs in public logs
- ❌ Skip signature verification
- ❌ Allow arbitrary amounts without validation

### Add Rate Limiting (Firebase)

```javascript
const rateLimit = {};

function isRateLimited(userId, limit = 5, windowMs = 60000) {
  const now = Date.now();
  if (!rateLimit[userId]) {
    rateLimit[userId] = [];
  }
  
  // Remove old requests
  rateLimit[userId] = rateLimit[userId].filter(
    time => now - time < windowMs
  );
  
  if (rateLimit[userId].length >= limit) {
    return true;
  }
  
  rateLimit[userId].push(now);
  return false;
}

// In initiatePayment function:
if (isRateLimited(userId, 5, 60000)) {
  return res.status(429).json({
    success: false,
    error: 'Too many requests. Please try again later.'
  });
}
```

---

## Step 7: Webhook Configuration

### Configure ICICI Callback URL

1. Login to: https://pgportal.icicibank.com/v2/pgmp/login
2. Go to: Settings > API Configuration
3. Set Callback URL to:
   ```
   https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/paymentCallback
   ```
4. Replace `us-central1` with your Firebase region
5. Replace `YOUR_PROJECT_ID` with your Firebase project ID

### Find Your Firebase Function URL

```bash
firebase functions:list

# Output:
# Function        Status  Trigger             URL
# initiatePayment ACTIVE  HTTP                https://us-central1-your-project.cloudfunctions.net/initiatePayment
# paymentCallback ACTIVE  HTTP                https://us-central1-your-project.cloudfunctions.net/paymentCallback
```

---

## Step 8: Production Checklist

- [ ] ICICI merchant key stored in Secret Manager
- [ ] Firebase Functions deployed and tested
- [ ] CORS configured for your app domain
- [ ] App Check enabled for functions
- [ ] Webhook URL configured in ICICI Dashboard
- [ ] Firestore security rules updated
- [ ] Error logging configured
- [ ] Payment success/failure notifications set up
- [ ] Invoice generation implemented
- [ ] Refund logic tested
- [ ] Rate limiting configured
- [ ] Monitoring and alerts set up

---

## Step 9: Handle Success/Failure Scenarios

### Success Handler

```dart
Future<void> _handlePaymentSuccess(String orderId) async {
  // 1. Update local app state
  setState(() => _isSubscriptionActive = true);
  
  // 2. Show success dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Payment Successful'),
      content: Text('Your subscription is now active!'),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Done'),
        ),
      ],
    ),
  );
  
  // 3. Navigate to subscription details
  Future.delayed(Duration(seconds: 2), () {
    Navigator.pushReplacementNamed(context, '/subscription-active');
  });
}
```

### Failure Handler

```dart
Future<void> _handlePaymentFailure(String error) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Payment Failed'),
      content: Text(error),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _retryPayment();
          },
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

---

## Step 10: Monitor and Debug

### View Firebase Function Logs

```bash
# Live logs
firebase functions:log --follow

# Last 50 logs
firebase functions:log

# Filter by function
firebase functions:log --filter="initiatePayment"

# Last 24 hours
firebase functions:log --limit=50
```

### Check Payment Status in Firestore

Console Query:
```
db.collection("payments")
  .where("userId", "==", "user_uuid")
  .where("status", "==", "SUCCESS")
  .orderBy("completedAt", "desc")
  .limit(10)
  .get()
```

### Enable Debugging in Flutter

```dart
// Set Firebase Functions to use local emulator
if (kDebugMode) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

---

## Troubleshooting

### Issue: "Unauthorized - No auth token"
**Solution:** Ensure user is authenticated before calling functions
```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Redirect to login
  Navigator.pushNamed(context, '/login');
}
```

### Issue: "Invalid response from ICICI API"
**Check:**
- Merchant MID is correct
- Merchant key is correct
- Hash generation matches ICICI format
- All required fields are present

### Issue: "CORS error in browser"
**Solution:** Update CORS in Firebase Functions
```javascript
cors: ["https://yourdomain.com", "https://www.yourdomain.com"]
```

### Issue: "Payment status shows PENDING forever"
**Solution:** Implement polling with exponential backoff
```dart
Future<void> _pollPaymentStatus(String orderId) async {
  int attempts = 0;
  while (attempts < 12) { // Max 2 minutes
    final status = await _paymentService.checkPaymentStatus(
      orderId: orderId,
      customerId: user.uid,
    );
    
    if (status.status != 'PENDING') {
      break;
    }
    
    await Future.delayed(Duration(seconds: 10 + (attempts * 5)));
    attempts++;
  }
}
```

---

## Support Resources

**ICICI Documentation:**
- Portal: https://pgportal.icicibank.com
- Support: msintegration@icici.bank.in
- Dashboard: https://pgportal.icicibank.com/v2/pgmp/login

**Firebase Documentation:**
- Cloud Functions: https://firebase.google.com/docs/functions
- Cloud Firestore: https://firebase.google.com/docs/firestore

**Your Contact:**
- Dominic Savio: dominicsaviod@gmail.com
- Mobile: +91-9900433466

---

## Quick Reference: API Endpoints

| Function | URL | Method |
|----------|-----|--------|
| Initiate Payment | /initiatePayment | POST |
| Check Status | /checkPaymentStatus | POST |
| Process Refund | /processRefund | POST |
| Payment Callback | /paymentCallback | POST |

---

**Last Updated:** May 4, 2026
**Version:** 1.0 - LIVE Integration Guide
