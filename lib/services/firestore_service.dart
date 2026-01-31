import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a collection reference rooted under:
  /// main (coll) -> {appName} (doc) -> {collectionName} (coll)
  /// If `scope` is provided, it uses that as the appName. Otherwise, it uses the current global AppName from ThemeService.
  CollectionReference<Map<String, dynamic>> collection(
    String collectionName, {
    String? scope,
  }) {
    final appName = scope ?? ThemeService.instance.appName;
    return _db.collection('main').doc(appName).collection(collectionName);
  }

  // Collection reference for subscriptions (Global or App specific?)
  // Subscriptions are usually global for the 'Platform Provider' (Rooks),
  // but if we want them isolated, they should be in the app scope or a separate global one.
  // For now, let's keep subscriptions global to the Platform Provider logic if needed,
  // OR if this is 'admin' logic, maybe it lives in a special admin place.
  // Current implementation points to 'main/CurrentApp/subscriptions' which might vary.
  // Let's explicitly scope subscriptions if they track the *User's* subscription to Rooks.
  // If 'subscriptions' means 'This App's Subscribers', it goes in the App Scope.
  // Based on context, this seems to be the White Label Customer's subscription to Rooks.
  // So it should probably be in a master collection or consistently scoped.
  // Let's assume 'subscriptions' acts on the current context for now, but be careful.
  CollectionReference get subscriptionsRef => _db.collection('subscriptions');
  // CHANGED: Moved out of 'main/appName' to global 'subscriptions' to track White Label Clients properly across the platform.

  // --- Global User Directory ---
  // Maps UID -> AppName/TenantID
  Future<void> saveUserDirectory({
    required String uid,
    required String appName,
    required String role,
  }) async {
    await _db.collection('global_user_directory').doc(uid).set({
      'appName': appName,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserAppAssociation(String uid) async {
    try {
      final doc = await _db.collection('global_user_directory').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['appName'] as String?;
      }
    } catch (_) {}
    return null;
  }

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

  // --- Referral Code Logic ---

  // Check if a referral code matches any active subscription/app
  // Returns the appName associated with the code if valid, null otherwise.
  Future<String?> validateReferralCode(String code) async {
    try {
      final doc = await _db.collection('referral_codes').doc(code).get();
      if (doc.exists) {
        // Return the appName or adminUid linked to this code
        return doc.data()?['appName'] as String?;
      }
    } catch (e) {
      // debugPrint('Error checking referral code: $e');
    }
    return null;
  }

  // Save a new referral code linked to an app
  Future<void> saveReferralCode({
    required String code,
    required String appName,
    required String adminUid,
  }) async {
    await _db.collection('referral_codes').doc(code).set({
      'code': code,
      'appName': appName,
      'adminUid': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }
}
