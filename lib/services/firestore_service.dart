import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a collection reference rooted under:
  /// main (coll) -> {appName} (doc) -> {collectionName} (coll)
  CollectionReference<Map<String, dynamic>> collection(String collectionName) {
    final appName = ThemeService.instance.appName;
    // Special case for 'admin' to ensure it matches the singular requirement in spec if needed
    // but usually, we just use the name passed.
    return _db.collection('main').doc(appName).collection(collectionName);
  }

  // Collection reference for subscriptions
  CollectionReference get subscriptionsRef => collection('subscriptions');

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return _db.runTransaction(updateFunction);
  }

  // Create/update current subscription for a user
  Future<void> upsertSubscription({
    required String uid,
    required String planName,
    required bool isYearly,
    required int price,
    int? originalPrice,
    String paymentMethod = 'unknown',
    Map<String, dynamic>? brandingData,
  }) async {
    final now = DateTime.now();
    final nextBilling = isYearly
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);

    final data = {
      'planName': planName,
      'isYearly': isYearly,
      'price': price,
      'originalPrice': originalPrice,
      'paymentMethod': paymentMethod,
      'status': 'active',
      'startedAt': now.toIso8601String(),
      'nextBillingAt': nextBilling.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (brandingData != null) {
      data['branding'] = brandingData;
    }

    // Save to valid firestore path: [dbName]/main/subscriptions/{uid}
    await subscriptionsRef.doc(uid).set(data, SetOptions(merge: true));
  }

  // Stream subscription for a specific user
  Stream<Map<String, dynamic>?> streamSubscription(String uid) {
    return subscriptionsRef.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    });
  }

  // Update only branding data for a user
  Future<void> updateBranding({
    required String uid,
    required Map<String, dynamic> brandingData,
  }) async {
    await subscriptionsRef.doc(uid).set({
      'branding': brandingData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Create an app-specific collection to store branding configuration
  Future<void> saveAppBranding({
    required String appName,
    required Map<String, dynamic> brandingData,
  }) async {
    await collection(appName).doc('branding').set({
      ...brandingData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
