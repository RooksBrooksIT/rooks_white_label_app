import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a collection reference rooted under:
  /// {organizationName}_{createdDate} (coll) -> {documentId} (doc) -> {subCollectionName} (coll)
  /// This follows the format: OrganizationName_createdDate
  /// Standardized tenant collection path: {tenantId} (coll) -> data (doc) -> {subCollection} (coll)
  CollectionReference<Map<String, dynamic>> collection(
    String collectionName, {
    String? tenantId,
    String? appId,
  }) {
    final effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
    final effectiveApp = appId ?? 'data';
    return _db
        .collection(effectiveTenant)
        .doc(effectiveApp)
        .collection(collectionName);
  }

  /// Exposes collectionGroup query
  Query<Map<String, dynamic>> collectionGroup(String collectionPath) {
    return _db.collectionGroup(collectionPath);
  }

  /// Tenant-specific reference for subscriptions
  CollectionReference<Map<String, dynamic>> subscriptionsRef({
    required String tenantId,
    String? appId,
  }) => collection('subscriptions', tenantId: tenantId, appId: appId);

  /// Tenant-specific reference for referral codes
  CollectionReference<Map<String, dynamic>> referralCodesRef({
    required String tenantId,
    String? appId,
  }) => collection('referral_codes', tenantId: tenantId, appId: appId);

  /// Tenant-specific reference for branding
  DocumentReference<Map<String, dynamic>> brandingDoc({
    required String tenantId,
    String? appId,
  }) => collection('branding', tenantId: tenantId, appId: appId).doc('config');

  // --- Global User Directory ---
  // Maps UID -> AppName/TenantID
  Future<void> saveUserDirectory({
    required String uid,
    required String tenantId,
    required String role,
    String? appName,
  }) async {
    // 1. Local tenant mapping (for tenant-specific user management)
    await collection('users', tenantId: tenantId).doc(uid).set({
      'tenantId': tenantId,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Global lookup (for routing during login)
    await _db.collection('global_user_directory').doc(uid).set({
      'tenantId': tenantId,
      'appName': appName,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserTenantAssociation(String uid) async {
    try {
      final doc = await _db.collection('global_user_directory').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['tenantId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// New: Get User Role and Org/App associations
  Future<Map<String, dynamic>?> getUserMetadata(String uid) async {
    try {
      final doc = await _db.collection('global_user_directory').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return _db.runTransaction(updateFunction);
  }

  // Create/update current subscription for a tenant user
  Future<void> upsertSubscription({
    required String uid,
    required String tenantId,
    required String planName,
    required bool isYearly,
    bool isSixMonths = false,
    required int price,
    int? originalPrice,
    String paymentMethod = 'unknown',
    Map<String, dynamic>? brandingData,
    String? appId,
    String? customerMobile, // stored for future payment lookups
  }) async {
    final now = DateTime.now();
    final nextBilling = isYearly
        ? DateTime(now.year + 1, now.month, now.day)
        : (isSixMonths
              ? DateTime(now.year, now.month + 6, now.day)
              : DateTime(now.year, now.month + 1, now.day));

    final data = <String, dynamic>{
      'planName': planName,
      'isYearly': isYearly,
      'isSixMonths': isSixMonths,
      'price': price,
      'originalPrice': originalPrice,
      'paymentMethod': paymentMethod,
      'status': 'active',
      'startedAt': now.toIso8601String(),
      'nextBillingAt': nextBilling.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (customerMobile != null && customerMobile.isNotEmpty)
        'customerMobile': customerMobile,
    };

    if (brandingData != null) {
      data['branding'] = brandingData;
    }

    await subscriptionsRef(
      tenantId: tenantId,
      appId: appId,
    ).doc(uid).set(data, SetOptions(merge: true));
  }

  /// Check if a user has an active subscription within a tenant
  /// Also checks if the subscription has expired based on nextBillingAt
  Future<bool> hasActiveSubscription({
    required String uid,
    required String tenantId,
    String? appId,
  }) async {
    try {
      final doc = await subscriptionsRef(
        tenantId: tenantId,
        appId: appId,
      ).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['status'] != 'active') return false;

        // Check if subscription has expired
        final nextBillingStr = data['nextBillingAt'] as String?;
        if (nextBillingStr != null) {
          final nextBilling = DateTime.tryParse(nextBillingStr);
          if (nextBilling != null && DateTime.now().isAfter(nextBilling)) {
            // Subscription has expired — mark as expired and deactivate user
            await subscriptionsRef(
              tenantId: tenantId,
              appId: appId,
            ).doc(uid).update({'status': 'expired'});
            await setUserActiveStatus(
              uid: uid,
              tenantId: tenantId,
              active: false,
            );
            return false;
          }
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Set the active status flag on a user document
  Future<void> setUserActiveStatus({
    required String uid,
    required String tenantId,
    required bool active,
  }) async {
    await collection(
      'users',
      tenantId: tenantId,
    ).doc(uid).update({'active': active});
  }

  // Stream subscription for a specific user within a tenant
  Stream<Map<String, dynamic>?> streamSubscription(
    String uid,
    String tenantId, {
    String? appId,
  }) {
    return subscriptionsRef(
      tenantId: tenantId,
      appId: appId,
    ).doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    });
  }

  // Update only branding data for a tenant
  Future<void> updateBranding({
    required String tenantId,
    required Map<String, dynamic> brandingData,
    String? appId,
  }) async {
    await brandingDoc(tenantId: tenantId, appId: appId).set({
      ...brandingData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Create an app-specific collection to store branding configuration
  Future<void> saveAppBranding({
    required String tenantId,
    required Map<String, dynamic> brandingData,
    String? appId,
  }) async {
    await brandingDoc(
      tenantId: tenantId,
      appId: appId,
    ).set({...brandingData, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // Fetch and apply branding configuration for a tenant
  Future<void> syncBranding(String tenantId, {String? appId}) async {
    try {
      final doc = await brandingDoc(tenantId: tenantId, appId: appId).get();
      if (doc.exists && doc.data() != null) {
        ThemeService.instance.loadFromMap({
          ...doc.data()!,
          'databaseName': tenantId, // Ensure databaseName is restored
        });
      }
    } catch (e) {
      // debugPrint('Error syncing branding: $e');
    }
  }

  // --- Referral Code Logic ---

  // Check if a referral code matches any active subscription/app
  // Returns the appName associated with the code if valid, null otherwise.
  Future<String?> validateReferralCode(
    String code,
    String tenantId, {
    String? appId,
  }) async {
    try {
      final doc = await referralCodesRef(
        tenantId: tenantId,
        appId: appId,
      ).doc(code).get();
      if (doc.exists) {
        return doc.data()?['tenantId'] as String?;
      }
    } catch (e) {
      // debugPrint('Error checking referral code: $e');
    }
    return null;
  }

  // Save a new referral code linked to a tenant
  Future<void> saveReferralCode({
    required String code,
    required String tenantId,
    required String adminUid,
    String? appId,
  }) async {
    await referralCodesRef(tenantId: tenantId, appId: appId).doc(code).set({
      'code': code,
      'tenantId': tenantId,
      'adminUid': adminUid,
      'appId': appId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  /// Global lookup for referral codes across all tenants (used during registration)
  Future<String?> validateGlobalReferralCode(String code) async {
    try {
      final snapshot = await _db
          .collectionGroup('referral_codes')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.get('tenantId') as String?;
      }
    } catch (e) {
      // debugPrint('Error validating global referral code: $e');
    }
    return null;
  }

  /// Get the referral code for a specific admin
  Future<String?> getReferralCodeForAdmin(String adminUid) async {
    try {
      final snapshot = await _db
          .collectionGroup('referral_codes')
          .where('adminUid', isEqualTo: adminUid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.get('code') as String?;
      }
    } catch (e) {
      // debugPrint('Error fetching admin referral code: $e');
    }
    return null;
  }
}
