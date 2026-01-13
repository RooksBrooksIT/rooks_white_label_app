import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference for subscriptions
  CollectionReference get subscriptionsRef => _db.collection('subscriptions');

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

    // Save to valid firestore path: subscriptions/{uid}
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
}
