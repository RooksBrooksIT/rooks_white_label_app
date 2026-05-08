# ICICI Payment Integration - Step-by-Step Setup Guide

## Pre-Setup Requirements Checklist

- [x] UAT integration completed
- [x] ICICI LIVE credentials received
- [x] ICICI Dashboard access: https://pgportal.icicibank.com
- [x] Firebase project created
- [x] Flutter app with Firebase initialized
- [ ] Google Cloud SDK installed
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Node.js 18+ installed

---

## PART 1: Secure Key Storage (30 minutes)

### 1.1 Get Your ICICI Merchant Key

**Steps:**
1. Login: https://pgportal.icicibank.com/v2/pgmp/login
2. Navigate: Account > Settings > Key Management
3. Click: "Generate Key" or "Download Key"
4. Copy the key string (keep it safe!)

**Your Details:**
```
Merchant MID: 100000000429484
Aggregator ID: 100000000429483
Merchant Key: [PASTE HERE FROM ICICI DASHBOARD]
```

### 1.2 Store in Firebase Secret Manager (RECOMMENDED)

**Method 1: Via Google Cloud Console**

1. Open: https://console.cloud.google.com/security/secret-manager
2. Click "Create Secret"
3. Name: `ICICI_MERCHANT_KEY`
4. Value: [paste your key]
5. Create
6. Repeat for:
   - `ICICI_MERCHANT_MID` = 100000000429484
   - `ICICI_AGGREGATOR_ID` = 100000000429483

**Grant Firebase Functions Access:**

```bash
# Get your Firebase service account email
gcloud config get-value project

# Grant access to each secret
gcloud secrets add-iam-policy-binding ICICI_MERCHANT_KEY \
  --member=serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding ICICI_MERCHANT_MID \
  --member=serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding ICICI_AGGREGATOR_ID \
  --member=serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

**Method 2: Via .env File (for local testing only)**

Create `functions/.env.local`:
```
ICICI_MERCHANT_MID=100000000429484
ICICI_MERCHANT_KEY=your_key_from_icici_dashboard
ICICI_AGGREGATOR_ID=100000000429483
ICICI_BASE_URL=https://pgpay.icicibank.com
ICICI_INITIATE_SALE_URL=https://pgpay.icicibank.com/pg/api/v2/initiateSale
ICICI_COMMAND_URL=https://pgpay.icicibank.com/pg/api/command
NODE_ENV=production
```

⚠️ **NEVER commit .env.local to git!**

Add to `.gitignore`:
```
functions/.env*.local
```

---

## PART 2: Firebase Functions Setup (45 minutes)

### 2.1 Install Dependencies

```bash
cd functions
npm install
```

### 2.2 Copy Payment Functions Files

Copy these files to your functions directory:

**From provided files:**
- `iciciPaymentService.js` → `functions/src/iciciPaymentService.js`
- `iciciPaymentFunctions.js` → `functions/src/iciciPaymentFunctions.js`

### 2.3 Update functions/index.js

Add this to the end of `functions/index.js`:

```javascript
// ===== ICICI Payment Functions =====
const {
  initiatePayment,
  checkPaymentStatus,
  processRefund,
  paymentCallback,
  testPaymentFlow
} = require('./src/iciciPaymentFunctions');

exports.initiatePayment = initiatePayment;
exports.checkPaymentStatus = checkPaymentStatus;
exports.processRefund = processRefund;
exports.paymentCallback = paymentCallback;
exports.testPaymentFlow = testPaymentFlow;
```

### 2.4 Test Locally (Optional but Recommended)

```bash
# Start Firebase emulator
firebase emulators:start --only functions

# Test function via UI at:
# http://localhost:4000/log
```

### 2.5 Deploy to Firebase

```bash
# Login to Firebase
firebase login

# Set project
firebase use rooks-white-label-app  # Replace with your project ID

# Deploy
firebase deploy --only functions

# Output will show your function URLs:
# ✔ functions[initiatePayment]: https://us-central1-rooks-....cloudfunctions.net/initiatePayment
# ✔ functions[checkPaymentStatus]: https://us-central1-rooks-....cloudfunctions.net/checkPaymentStatus
# ... etc
```

### 2.6 Verify Deployment

```bash
# List functions
firebase functions:list

# Watch logs
firebase functions:log --follow
```

---

## PART 3: Configure ICICI Webhook (15 minutes)

### 3.1 Get Your Callback Function URL

From the deployment output above, find the URL for `paymentCallback`:
```
https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/paymentCallback
```

### 3.2 Configure in ICICI Dashboard

1. Login: https://pgportal.icicibank.com/v2/pgmp/login
2. Go: Settings > API Configuration > Callback URL
3. Paste: `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/paymentCallback`
4. Save

### 3.3 Configure Return URL (Optional)

If ICICI redirects users back to your app:
1. Add to your app domain settings
2. Example: `https://yourdomain.com/payment-success`

---

## PART 4: Flutter App Integration (60 minutes)

### 4.1 Add Dependencies

Update `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^25.0.0
  firebase_auth: ^4.15.0
  cloud_functions: ^4.10.0
  http: ^1.1.0
  uuid: ^4.0.0
```

Install:
```bash
flutter pub get
```

### 4.2 Copy Service Files

Copy to `lib/services/`:
- `payment_service.dart`
- `payment_utils.dart`

### 4.3 Initialize Firebase in main.dart

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

### 4.4 Add Payment Screen

Copy `payment_processing_screen.dart` to `lib/subscription/`

### 4.5 Integrate into Your App

In your subscription page:

```dart
import 'services/payment_service.dart';
import 'utils/payment_utils.dart';

class SubscriptionPage extends StatefulWidget {
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _paymentService = PaymentService();

  Future<void> _buySubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final orderId = PaymentUtils.generateOrderId();
    
    final response = await _paymentService.initiatePayment(
      orderId: orderId,
      amount: 499.00,
      customerId: user.uid,
      mobileNumber: user.phoneNumber ?? '',
      emailId: user.email ?? '',
      productDescription: '3-Month Premium Subscription',
    );

    if (response.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentProcessingScreen(
            orderId: orderId,
            amount: 499.00,
            productDescription: '3-Month Premium Subscription',
          ),
        ),
      );
    } else {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('₹499', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('3-Month Premium Access'),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _buySubscription,
              icon: Icon(Icons.payment),
              label: Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## PART 5: Testing with ₹1 (30 minutes)

### 5.1 Test Payment Initiation

```dart
// In your test/payment_test.dart
void testPayment() async {
  final paymentService = PaymentService();
  
  final response = await paymentService.initiatePayment(
    orderId: 'TEST_ORDER_${DateTime.now().millisecondsSinceEpoch}',
    amount: 1.00, // Test with ₹1
    customerId: 'test_user_id',
    mobileNumber: '9900433466',
    emailId: 'dominicsaviod@gmail.com',
    productDescription: 'Test Payment',
  );

  print('Response: ${response.success}');
  print('Order ID: ${response.orderId}');
  if (response.error != null) {
    print('Error: ${response.error}');
  }
}
```

### 5.2 Check Firebase Logs

```bash
firebase functions:log --follow
```

Look for:
```
[PAYMENT] Initiating sale for Order: TEST_ORDER_..., Amount: 1.00
[PAYMENT] Hash generated for Order: TEST_ORDER_...
```

### 5.3 Verify Firestore Record

In Firebase Console:
1. Go: Firestore Database
2. Collection: `payments`
3. Document: Your ORDER_ID
4. Check:
   - `status`: Should be "INITIATED"
   - `amount`: 1.00
   - `iciciResponse`: Full response from ICICI

### 5.4 Complete Payment in ICICI Gateway

1. Your payment function should return a redirect URL
2. Open that URL in browser
3. Enter test card details from ICICI
4. Complete payment
5. Return to app

### 5.5 Verify Payment Success

```bash
# Check status via function call
curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/checkPaymentStatus \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "TEST_ORDER_xxx",
    "customerId": "test_user_id"
  }'
```

Expected response:
```json
{
  "success": true,
  "orderId": "TEST_ORDER_xxx",
  "status": "SUCCESS",
  "amount": 1.00,
  "transactionId": "TXN_ID_FROM_ICICI"
}
```

---

## PART 6: Full Integration Testing (2 hours)

### 6.1 Test Workflow

```
1. User clicks "Buy Subscription" → 499.00
   ↓
2. initiatePayment() → Firebase Function
   ↓
3. Firebase signs request with merchant key
   ↓
4. Call ICICI InitiateSale API
   ↓
5. Get redirect URL from ICICI
   ↓
6. Open payment gateway (WebView or redirect)
   ↓
7. User enters card details
   ↓
8. ICICI processes payment
   ↓
9. ICICI calls paymentCallback() → Firebase Function
   ↓
10. Firebase verifies signature
    ↓
11. Update Firestore (status: SUCCESS)
    ↓
12. Send notification to user
    ↓
13. Activate subscription
```

### 6.2 Test Cases

**Test 1: Successful Payment**
- Amount: ₹1
- Expected: status = SUCCESS

**Test 2: Failed Payment**
- Amount: ₹0 (should fail validation)
- Expected: error message

**Test 3: Check Status Endpoint**
- Call checkPaymentStatus with valid orderId
- Expected: Latest payment status

**Test 4: Refund**
- Complete payment → Call processRefund()
- Expected: Refund initiated

**Test 5: Rate Limiting**
- Call initiatePayment() 10 times in 60 seconds
- Expected: 429 error after limit

---

## PART 7: Production Deployment (30 minutes)

### 7.1 Update CORS

In `functions/src/iciciPaymentFunctions.js`:

```javascript
cors: ["https://yourdomain.com", "https://www.yourdomain.com", "https://app.yourdomain.com"]
```

### 7.2 Enable App Check

In Firebase Console:
1. Go: Project Settings > App Check
2. Enable for your app
3. Get reCAPTCHA token in Flutter:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAppCheck.instance.activate(
    webRecaptchaSiteKey: 'YOUR_RECAPTCHA_SITE_KEY',
  );
  
  runApp(const MyApp());
}
```

### 7.3 Set Environment Variables

In Firebase Functions:
```bash
# Set for production
firebase functions:config:set icici.merchant_mid="100000000429484"
firebase functions:config:set icici.merchant_key="your_key"
firebase functions:config:set icici.aggregator_id="100000000429483"

# Or use Secret Manager (RECOMMENDED)
```

### 7.4 Final Deployment

```bash
firebase deploy --only functions:initiatePayment,functions:checkPaymentStatus,functions:processRefund,functions:paymentCallback
```

### 7.5 Monitor Live

```bash
firebase functions:log --follow
```

---

## PART 8: Monitoring & Support

### Monitor Payment Metrics

```bash
# View errors in last hour
firebase functions:log --limit=100 | grep ERROR

# View all payment transactions
firebase functions:log --follow | grep PAYMENT
```

### Set Up Alerts

In Google Cloud Console:
1. Monitoring > Alerting > Create Policy
2. Condition: Cloud Functions > Execution error count
3. Notification: Email/Slack

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Invalid merchant key" | Verify key in ICICI dashboard |
| "CORS error" | Update CORS in Firebase function |
| "Hash mismatch" | Check key and hash generation |
| "Callback not received" | Verify URL in ICICI dashboard |
| "Status shows PENDING" | Wait for callback or check ICICI logs |

### Support Contacts

- **ICICI:** msintegration@icici.bank.in
- **Firebase:** https://firebase.google.com/support
- **Your Team:** dominicsaviod@gmail.com

---

## Final Checklist

- [ ] ICICI merchant key securely stored
- [ ] Firebase Functions deployed
- [ ] Payment service initialized in Flutter
- [ ] ₹1 test payment successful
- [ ] Full ₹499 payment tested
- [ ] Callback webhook working
- [ ] Firestore records created correctly
- [ ] Status check endpoint working
- [ ] Refund functionality tested
- [ ] Error handling implemented
- [ ] CORS configured for production
- [ ] App Check enabled
- [ ] Monitoring set up
- [ ] User notifications working

---

**Congratulations! You're ready for LIVE payments! 🎉**

*For questions or issues, contact ICICI at msintegration@icici.bank.in*
