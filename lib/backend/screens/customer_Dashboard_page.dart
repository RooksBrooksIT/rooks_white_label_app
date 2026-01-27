import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class CustomerDashboardBackend {
  static Future<Map<String, String?>> getStoredUserInfo(
    String defaultName,
    String defaultPhone,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'userName': prefs.getString('userName') ?? defaultName,
      'phoneNumber': prefs.getString('phoneNumber') ?? defaultPhone,
    };
  }

  static Future<void> saveFcmToken(String phoneNumber) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && phoneNumber.isNotEmpty) {
        await FirestoreService.instance
            .collection('UserTokens')
            .doc(phoneNumber)
            .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Logout error: $e');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}
