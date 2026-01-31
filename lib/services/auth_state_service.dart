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
      if (additionalData != null &&
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
        ...?additionalData,
      };

      // Store in the specific Company's 'users' collection
      await FirestoreService.instance
          .collection('users', scope: targetScope)
          .doc(uid)
          .set(userData);

      // 2b. Register in Global Directory for Login Lookup
      // For Admins, this might need to be updated later when they name their app.
      if (role != 'admin') {
        // Admins haven't named their app yet usually.
        // Customers definitively belong to targetScope.
        await FirestoreService.instance.saveUserDirectory(
          uid: uid,
          appName: targetScope,
          role: role,
        );
      } else {
        // Optionally track admins too, though their appName might change during setup.
        // We'll mark them as 'pending_setup' or similar if needed,
        // but functionally BrandingCustomizationScreen handles the final binding.
      }

      // 3. Mark as registered locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsRegistered, true);
      await prefs.setString(_kUserRole, role);
      _isRegistered = true;
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

      // 1. Check Global Directory for App Association
      final associatedAvailableApp = await FirestoreService.instance
          .getUserAppAssociation(uid);
      String scope = ThemeService.instance.appName;

      if (associatedAvailableApp != null) {
        scope = associatedAvailableApp;
        // Update Local Theme Context immediately so subsequent calls use correct DB
        // We might need to fetch the full branding here too?
        // For now, at least set the appName so 'collection()' works.
        // Ideally we'd fetch branding from 'main/{scope}/branding'
        ThemeService.instance.updateTheme(
          primary: ThemeService.instance.primaryColor, // Keep current or fetch?
          secondary: ThemeService.instance.secondaryColor,
          backgroundColor: ThemeService.instance.backgroundColor,
          isDarkMode: ThemeService.instance.isDarkMode,
          fontFamily: ThemeService.instance.fontFamily,
          appName: scope,
        );
        // Note: Real app should fetch actual theme colors from Firestore here.
      }

      // Fetch user data from the specific Company DB
      final doc = await FirestoreService.instance
          .collection('users', scope: scope)
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
