import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firestore_service.dart';

/// Service to interact with ICICI Payment Gateway via Firebase Cloud Functions.
///
/// All ICICI API calls are proxied through the backend (createPaymentSession)
/// to avoid SSL certificate issues on Android and to keep secrets server-side.
/// The initiateRefund method still calls the backend Command API via the
/// existing processRefund Cloud Function.
class IciciService {
  IciciService._();
  static final IciciService instance = IciciService._();

  // ─── Cloud Function endpoints ─────────────────────────────────────────────
  // Actual deployed URL (from firebase deploy output)
  static String get _createSessionUrl =>
      dotenv.env['CLOUD_FUNCTION_CREATE_SESSION_URL'] ??
      'https://createpaymentsession-ltjv3mr7da-uc.a.run.app';

  static String get _processRefundUrl =>
      dotenv.env['CLOUD_FUNCTION_PROCESS_REFUND_URL'] ??
      'https://processrefund-ltjv3mr7da-uc.a.run.app';

  // ─── Return URL (intercepted by WebView) ──────────────────────────────────
  static final String returnUrl =
      dotenv.env['ICICI_RETURN_URL'] ??
      'https://paymentcallback-ltjv3mr7da-uc.a.run.app';

  // ─── Helper: unique merchant txn reference ────────────────────────────────
  String _generateMerchantTxnNo() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  // ─── Map ICICI payType → Cloud Function paymentMode ──────────────────────
  String _resolvePaymentMode(String payType) {
    switch (payType) {
      case '2':
        return 'CARD';
      case '3':
        return 'UPI';
      case '1':
      default:
        return 'NETBANKING';
    }
  }

  /// Fetches the customer's data (name and phone) from Firestore user profile.
  Future<Map<String, String>> fetchCustomerData(
    String uid,
    String tenantId,
  ) async {
    String phone = '';
    String name = 'Customer';
    try {
      final userDoc = await FirestoreService.instance
          .collection('users', tenantId: tenantId)
          .doc(uid)
          .get();
      final data = userDoc.data();
      phone =
          (data?['customerMobile'] as String?) ??
          (data?['phone'] as String?) ??
          '';
      name = (data?['name'] as String?) ?? 'Customer';
    } catch (e) {
      debugPrint('[IciciService] fetchCustomerData error: $e');
    }
    if (phone.isNotEmpty && !phone.startsWith('91')) {
      phone = '91$phone';
    }
    return {'name': name, 'phone': phone.isEmpty ? '919999999999' : phone};
  }

  /// Initiate a payment session via the Firebase Cloud Function.
  ///
  /// Replaces the old direct-to-ICICI HTTP call that caused:
  ///   HandshakeException: CERTIFICATE_VERIFY_FAILED
  ///
  /// Returns a map with `merchantTxnNo` and `redirectUrl` on success,
  /// or `null` on failure.
  Future<Map<String, dynamic>?> initiateSale({
    required String amount,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    String payType = '1',
    String? uid,
    String? tenantId,
    String? appId,
    String planName = 'Subscription',
  }) async {
    try {
      // 1. Resolve payment mode
      final paymentMode = _resolvePaymentMode(payType);

      // 2. Get Firebase Auth ID token (required by createPaymentSession)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('[IciciService] ✗ No authenticated Firebase user');
        return null;
      }
      final String idToken = await firebaseUser.getIdToken() ?? '';
      final String userId = uid ?? firebaseUser.uid;

      // 3. Local reference ID for Firestore audit log
      final merchantTxnNo = _generateMerchantTxnNo();

      debugPrint(
        '[IciciService] ► initiateSale via Cloud Function | '
        'mode=$paymentMode | amount=$amount | txnRef=$merchantTxnNo',
      );

      // 4. Save audit record BEFORE the API call
      await saveSubscriptionPayment(
        payload: {
          'merchantTxnNo': merchantTxnNo,
          'amount': amount,
          'paymentMode': paymentMode,
          'planName': planName,
          'customerEmail': customerEmail,
          'customerMobile': customerMobile,
        },
        uid: userId,
        tenantId: tenantId,
        status: 'INITIATED',
      );

      // 5. Call Firebase Cloud Function (server-side → ICICI, no SSL issues)
      final response = await http
          .post(
            Uri.parse(_createSessionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'orderId': merchantTxnNo,
              'amount': double.tryParse(amount) ?? 0.0,
              'userId': userId,
              'paymentMode': paymentMode,
              'planName': planName,
              'email': customerEmail,
              'mobile': customerMobile,
              'tenantId': tenantId,
              'appId': appId,
            }),
          )
          .timeout(
            const Duration(seconds: 120),  // Match backend Cloud Function timeout (120s)
            onTimeout: () =>
                throw Exception('Cloud Function request timed out'),
          );

      debugPrint(
        '[IciciService] createPaymentSession response '
        '[${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          // Cloud Function returns txnId — use it as our merchantTxnNo
          final txnId = (data['txnId'] as String?) ?? merchantTxnNo;
          final redirectUrl =
              data['redirectUrl'] as String? ?? data['paymentUrl'] as String?;

          debugPrint(
            '[IciciService] ✓ Session created | txnId=$txnId | '
            'redirectUrl=$redirectUrl',
          );

          return {
            ...data,
            'merchantTxnNo': txnId,
            'redirectUrl': redirectUrl,
            'paymentUrl': redirectUrl,
          };
        } else {
          debugPrint(
            '[IciciService] ✗ createPaymentSession failed: ${data['error']}',
          );
          return null;
        }
      } else {
        debugPrint(
          '[IciciService] ✗ HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[IciciService] initiateSale error: $e');
      return null;
    }
  }

  /// Check the status of a transaction using the Command API via Cloud Function.
  Future<Map<String, dynamic>?> checkTransactionStatus({
    required String merchantTxnNo,
  }) async {
    try {
      debugPrint('[IciciService] checkTransactionStatus for: $merchantTxnNo');

      // Look up Firestore payments collection set by createPaymentSession
      final doc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(merchantTxnNo)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        debugPrint('[IciciService] Firestore status: ${data['status']}');
        return {'status': data['status'] ?? 'PENDING', ...data};
      }

      return null;
    } catch (e) {
      debugPrint('[IciciService] checkTransactionStatus error: $e');
      return null;
    }
  }

  /// Stream the status of a transaction for real-time updates.
  Stream<DocumentSnapshot> streamTransactionStatus({
    required String merchantTxnNo,
  }) {
    return FirebaseFirestore.instance
        .collection('payments')
        .doc(merchantTxnNo)
        .snapshots();
  }


  /// Save the ICICI initiation payload to Firestore for audit/reconciliation.
  Future<void> saveSubscriptionPayment({
    required Map<String, String> payload,
    String? uid,
    String? tenantId,
    String status = 'INITIATED',
  }) async {
    try {
      final docId =
          payload['merchantTxnNo'] ??
          DateTime.now().millisecondsSinceEpoch.toString();

      CollectionReference? ref;
      if (uid != null && tenantId != null) {
        ref = FirestoreService.instance
            .collection('users', tenantId: tenantId)
            .doc(uid)
            .collection('subscriptionPayment');
      } else {
        ref = FirebaseFirestore.instance.collection('subscriptionPayment');
      }

      await ref.doc(docId).set({
        ...payload,
        if (uid != null) 'uid': uid,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('[IciciService] Audit record saved: $docId');
    } catch (e) {
      debugPrint('[IciciService] saveSubscriptionPayment error: $e');
    }
  }

  /// Initiate a refund for a completed transaction via the backend.
  ///
  /// [merchantTxnNo] - The original merchant transaction number.
  /// [amount] - The refund amount as a string (e.g. "499").
  Future<Map<String, dynamic>?> initiateRefund({
    required String merchantTxnNo,
    required String amount,
  }) async {
    try {
      debugPrint(
        '[IciciService] initiateRefund | txnNo=$merchantTxnNo | amount=$amount',
      );

      // Get Firebase Auth token
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('[IciciService] initiateRefund: no authenticated user');
        return null;
      }
      final idToken = await firebaseUser.getIdToken() ?? '';

      final response = await http
          .post(
            Uri.parse(_processRefundUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'orderId': merchantTxnNo,
              'transactionId': merchantTxnNo,
              'refundAmount': double.tryParse(amount) ?? 0.0,
              'customerId': firebaseUser.uid,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Refund request timed out'),
          );

      debugPrint(
        '[IciciService] processRefund response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          '[IciciService] Refund HTTP error ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[IciciService] initiateRefund error: $e');
      return null;
    }
  }

  /// Save a payment transaction record to Firestore.
  Future<void> saveTransaction({
    required String uid,
    required String merchantTxnNo,
    required String amount,
    required String status,
    required String paymentMethod,
    String? planName,
    bool? isYearly,
    String? tenantId,
    String? appId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final ref = FirestoreService.instance.collection(
        'payment_transactions',
        tenantId: tenantId,
        appId: appId,
      );

      await ref.doc(merchantTxnNo).set({
        'uid': uid,
        'merchantTxnNo': merchantTxnNo,
        'amount': amount,
        'status': status,
        'paymentMethod': paymentMethod,
        'planName': planName,
        'isYearly': isYearly,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      });

      debugPrint('[IciciService] Transaction saved: $merchantTxnNo ($status)');
    } catch (e) {
      debugPrint('[IciciService] saveTransaction error: $e');
    }
  }
}
