import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/backend/screens/amc_customerlogin_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_brandandmodel_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_Engineer_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_barcode_scanner.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_amc_customer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_engineer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_customer_report_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_device_config_page.dart';
import 'package:subscription_rooks_app/frontend/screens/barcode_identifier.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_barcode_details.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';

class AuthStateService extends ChangeNotifier {
  AuthStateService._();
  static final AuthStateService instance = AuthStateService._();

  static const String _kIsRegistered = 'app_is_registered';
  static const String _kUserRole = 'user_role';
  static const String _kLastAdminPage = 'last_admin_page';
  static const String _kLastAdminPageArgs = 'last_admin_page_args';

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
        // If Firebase user exists, we consider it a registered session
        _isRegistered = true;
        await prefs.setBool(_kIsRegistered, true);
      }
    } catch (e) {
      debugPrint('Firebase not fully ready during AuthStateService.init: $e');
    }
  }

  /// Saves the last accessed admin page for session restoration
  Future<void> saveLastAdminPage(
    String pageName, {
    Map<String, dynamic>? args,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastAdminPage, pageName);
    if (args != null) {
      // Simple JSON-like storage for args if needed, or just specific keys
      // For now, focusing on page names as per requirements
      debugPrint('AuthStateService: Saving last admin page: $pageName');
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
        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('admin_email', email);
        await prefs.setString('admin_org_collection', targetScope);
        await prefs.setString('last_role', 'admin');

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

    final prefs = await SharedPreferences.getInstance();

    // Clear Admin session
    await prefs.remove('admin_isLoggedIn');
    await prefs.remove('admin_email');
    await prefs.remove('admin_org_collection');
    await prefs.remove(_kLastAdminPage);
    await prefs.remove(_kLastAdminPageArgs);

    // Clear Engineer session
    await prefs.remove('engineerName');
    await prefs.remove('engineerEmail');
    await prefs.remove('tenantId');

    // Clear Customer session
    await prefs.remove('email');
    await prefs.remove('databaseName');

    // Clear unified session flags
    await prefs.remove(_kIsRegistered);
    await prefs.remove(_kUserRole);

    _isRegistered = false;
    notifyListeners();
  }

  /// Determines the initial screen based on persisted login state
  Future<Widget> getInitialScreen() async {
    try {
      debugPrint('AuthStateService: Determining initial screen...');
      final prefs = await SharedPreferences.getInstance();

      // 1. Check for active Firebase Session (Recovery path)
      final user = auth.currentUser;
      if (user != null && !user.isAnonymous) {
        debugPrint(
          'AuthStateService: Firebase session found for ${user.email}',
        );
        final metadata = await FirestoreService.instance.getUserMetadata(
          user.uid,
        );
        if (metadata != null) {
          final role = metadata['role'] as String?;
          final tenantId = metadata['tenantId'] as String?;
          debugPrint(
            'AuthStateService: Recovered metadata - role: $role, tenant: $tenantId',
          );

          // Restore SharedPreferences flags to maintain consistency
          await prefs.setBool(_kIsRegistered, true);
          await prefs.setString(_kUserRole, role ?? 'user');

          if (tenantId != null) {
            await prefs.setString('tenantId', tenantId);
            await prefs.setString('databaseName', tenantId);
            // Initialize branding for the recovered tenant
            await FirestoreService.instance.syncBranding(tenantId);
          }

          if (role == 'admin') {
            await prefs.setBool('admin_isLoggedIn', true);
            await prefs.setString('admin_email', user.email ?? '');
            if (tenantId != null) {
              await prefs.setString('admin_org_collection', tenantId);
            }
            if (metadata.containsKey('name')) {
              await prefs.setString('appName', metadata['name'] ?? '');
            }

            final lastPage = prefs.getString(_kLastAdminPage);
            if (lastPage != null) return _getAdminPageWidget(lastPage);
            return const admindashboard();
          } else if (role == 'engineer') {
            final name = metadata['name'] ?? metadata['Username'] ?? '';
            await prefs.setString('engineerName', name);
            return EngineerPage(userEmail: user.email ?? '', userName: name);
          } else if (role == 'customer') {
            await prefs.setString('email', user.email ?? '');
            return const AMCCustomerMainPage();
          }
        }
      }

      // 2. Fallback to existing logic if no Firebase user or metadata not found
      // Check Admin
      final bool isAdminLoggedIn = await AdminLoginBackend.checkLoginStatus();
      debugPrint('AuthStateService: Admin logged in: $isAdminLoggedIn');
      if (isAdminLoggedIn) {
        final lastPage = prefs.getString(_kLastAdminPage);
        debugPrint('AuthStateService: Last admin page: $lastPage');
        if (lastPage != null) {
          return _getAdminPageWidget(lastPage);
        }
        return const admindashboard();
      }

      // Check Engineer
      final String? engineerName =
          await EngineerLoginBackend.checkLoginStatus();
      debugPrint('AuthStateService: Engineer logged in: $engineerName');
      if (engineerName != null) {
        return EngineerPage(userEmail: '', userName: engineerName);
      }

      // Check Customer
      final String? customerEmail = await AMCLoginBackend.checkLoginStatus();
      debugPrint('AuthStateService: Customer logged in: $customerEmail');
      if (customerEmail != null) {
        return const AMCCustomerMainPage();
      }

      debugPrint(
        'AuthStateService: No session found, checking for last used role',
      );
      final lastRole = prefs.getString('last_role');
      if (lastRole == 'admin') {
        return const AdminLogin();
      }

      return const RoleSelectionScreen();
    } catch (e) {
      debugPrint('AuthStateService: Error determining initial screen: $e');
      // Default to role selection on error
      return const RoleSelectionScreen();
    }
  }

  /// Maps page names back to Widgets
  Widget _getAdminPageWidget(String pageName) {
    switch (pageName) {
      case 'dashboard':
        return const admindashboard();
      case 'service_tickets':
        return const AdminPage_CusDetails(statusFilter: "");
      case 'brand_and_model':
        return const BrandModelPage();
      case 'engineer_reports':
        return const AdminEngineerReports();
      case 'barcode_scanner':
        return const AdminBarcodeScanner();
      case 'attendance':
        return const AdminAttendancePage();
      case 'attendance_reports':
        return const AdminAttendanceReportsPage();
      case 'create_amc':
        return const AMCCreatePage();
      case 'create_engineer':
        return const EngineerManagementPage();
      case 'service_reports':
        return CustomerReportGenerator();
      case 'device_config':
        return const AdminDeviceConfigurationPage();
      case 'barcode_hub':
        return const AdminBarcodeScanner();
      case 'identity':
        return const BarcodeIdentifierScreen(scannedBarcode: "");
      case 'barcode_details':
        return const AdminViewBarcodeDetails();
      case 'geo_location':
        return const AdminGeoLocationScreen(engineerId: '', engineerName: '');
      default:
        return const admindashboard();
    }
  }
}
