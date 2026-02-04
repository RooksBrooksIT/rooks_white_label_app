import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class AuthStateService extends ChangeNotifier {
  AuthStateService._();
  static final AuthStateService instance = AuthStateService._();

  static const String _kIsRegistered = 'app_is_registered';
  static const String _kUserRole = 'user_role';

  FirebaseAuth? _auth;
  FirebaseAuth get auth {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint('Failed to get FirebaseAuth instance: $e');
      }
    }
    return _auth!;
  }

  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;
  User? get currentUser => _auth?.currentUser;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isRegistered = prefs.getBool(_kIsRegistered) ?? false;

    try {
      _auth = FirebaseAuth.instance;
      // Also check if user is logged in via Firebase
      if (_auth?.currentUser != null) {
        _isRegistered = true;
        await prefs.setBool(_kIsRegistered, true);
      }
    } catch (e) {
      debugPrint('Firebase not fully ready during AuthStateService.init: $e');
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Safety check
      if (Firebase.apps.isEmpty) {
        return {'success': false, 'message': 'Firebase is not initialized.'};
      }

      debugPrint('Attempting to register user: $email with role: $role');

      // 1. Create user in Firebase Auth
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Determine proper scope (Company DB)
      String targetScope = ThemeService.instance.appName;

      if (role == 'admin') {
        // Generate dynamic collection name: OrganizationName_YYYYMMDD
        final now = DateTime.now();
        final dateStr =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
        // Clean organization name (remove spaces)
        final cleanOrgName = name.replaceAll(' ', '');
        targetScope = "${cleanOrgName}_$dateStr";
      } else if (additionalData != null &&
          additionalData.containsKey('linkedAppName')) {
        targetScope = additionalData['linkedAppName'];
      }

      // 2. Store details in Firestore (Isolated to Company DB)
      final userData = {
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'registeredAt': FieldValue.serverTimestamp(),
        'isApproved': role == 'admin' ? true : false,
        'tenantId': targetScope, // Store the tenant ID or scope
        ...?additionalData,
      };

      // Store in the specific Company's 'users' collection
      await FirestoreService.instance
          .collection('users', tenantId: targetScope)
          .doc(uid)
          .set(userData);

      // 2b. Register in Global Directory for Login Lookup
      // Every user (including Admin) must be in the global directory to be found during login
      await FirestoreService.instance.saveUserDirectory(
        uid: uid,
        tenantId: targetScope,
        role: role,
      );

      // 3. Mark as registered locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true);
      await prefs.setString(_kUserRole, role);
      _isRegistered = true;

      if (role == 'admin') {
        ThemeService.instance.updateTheme(
          primary: ThemeService.instance.primaryColor,
          secondary: ThemeService.instance.secondaryColor,
          backgroundColor: ThemeService.instance.backgroundColor,
          isDarkMode: ThemeService.instance.isDarkMode,
          fontFamily: ThemeService.instance.fontFamily,
          appName: targetScope,
          databaseName: targetScope,
        );
      }
      notifyListeners();

      return {'success': true, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration Error (FirebaseAuth): ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': 'Auth Error: ${e.message} (Code: ${e.code})',
      };
    } catch (e) {
      debugPrint('Registration Error (App): $e');
      return {'success': false, 'message': 'System Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // 1. Check Global Directory for Tenant Association
      final associatedTenant = await FirestoreService.instance
          .getUserTenantAssociation(uid);
      String scope = ThemeService.instance.appName;

      if (associatedTenant != null) {
        scope = associatedTenant;
        // Update Local Theme Context immediately so subsequent calls use correct DB
        // Fetch actual branding from 'branding/config' under the tenant
        final brandingDoc = await FirestoreService.instance
            .brandingDoc(tenantId: scope)
            .get();

        Map<String, dynamic>? brandingData;
        if (brandingDoc.exists) {
          brandingData = brandingDoc.data();
        }

        ThemeService.instance.updateTheme(
          primary: brandingData?['primaryColor'] != null
              ? Color(brandingData!['primaryColor'])
              : ThemeService.instance.primaryColor,
          secondary: brandingData?['secondaryColor'] != null
              ? Color(brandingData!['secondaryColor'])
              : ThemeService.instance.secondaryColor,
          backgroundColor: brandingData?['backgroundColor'] != null
              ? Color(brandingData!['backgroundColor'])
              : ThemeService.instance.backgroundColor,
          isDarkMode:
              brandingData?['useDarkMode'] ?? ThemeService.instance.isDarkMode,
          fontFamily:
              brandingData?['fontFamily'] ?? ThemeService.instance.fontFamily,
          appName: brandingData?['appName'] ?? scope,
          databaseName: scope,
          logoUrl: brandingData?['logoUrl'],
        );
      }

      // Fetch user data from the specific Company DB
      final doc = await FirestoreService.instance
          .collection('users', tenantId: scope)
          .doc(uid)
          .get();

      if (!doc.exists) {
        // Fallback: Check global/default bucket if not found in specific scope?
        // Or return error.
        return {'success': false, 'message': 'User record not found in $scope'};
      }

      final userData = doc.data() as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true); // Ensure this is set
      await prefs.setString(_kUserRole, userData['role'] ?? 'user');
      _isRegistered = true;
      notifyListeners();

      return {'success': true, 'userData': userData};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await auth.signOut();
    // We don't necessarily clear _kIsRegistered because the app *is* registered on this device.
    // The user just needs to log in again.
  }
}
