import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminLoginBackend {
  static Future<bool> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('admin_isLoggedIn') ?? false;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      QuerySnapshot snapshot = await FirestoreService.instance
          .collection('admin')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('admin_isLoggedIn', true);
        await prefs.setString('admin_email', email);
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Invalid email or password. Please try again.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String name,
  ) async {
    try {
      // Check if admin already exists
      QuerySnapshot snapshot = await FirestoreService.instance
          .collection('admin')
          .where('email', isEqualTo: email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Admin with this email already exists.',
        };
      }

      // Format organization name: OrganizationName_YYYYMMDD
      final now = DateTime.now();
      final dateStr =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final orgCollectionName = "${name.replaceAll(' ', '')}_$dateStr";

      // Store in the organizational root collection
      await FirestoreService.instance
          .collection('admin', tenantId: orgCollectionName)
          .doc(name)
          .set({
            'email': email,
            'password': password,
            'name': name,
            'tenantId': orgCollectionName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Also mark in global directory if needed or just use SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_org_collection', orgCollectionName);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
