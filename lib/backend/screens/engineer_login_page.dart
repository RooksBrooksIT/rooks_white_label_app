import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class EngineerLoginBackend {
  static Future<String?> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('engineerName');
  }

  static Future<void> registerFcmToken(String engineerName) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? token = await messaging.getToken();

      if (token != null && engineerName.isNotEmpty) {
        await FirestoreService.instance
            .collection('EngineerTokens')
            .doc(engineerName)
            .set({'token': token}, SetOptions(merge: true));
      }

      messaging.onTokenRefresh.listen((newToken) {
        FirestoreService.instance
            .collection('EngineerTokens')
            .doc(engineerName)
            .set({'token': newToken}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: username)
          .where('Password', isEqualTo: password)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('engineerName', username);
        await registerFcmToken(username);
        return {'success': true, 'username': username};
      } else {
        return {
          'success': false,
          'message': 'Invalid credentials. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
    String username,
    String phone,
    String newPass,
  ) async {
    try {
      final query = await FirestoreService.instance
          .collection('EngineerLogin')
          .where('Username', isEqualTo: username)
          .where('Phone', isEqualTo: phone)
          .get();

      if (query.docs.isNotEmpty) {
        final docId = query.docs.first.id;
        await FirestoreService.instance
            .collection('EngineerLogin')
            .doc(docId)
            .update({'Password': newPass});
        return {'success': true, 'message': 'Password updated successfully.'};
      } else {
        return {
          'success': false,
          'message': 'Username or phone number is incorrect.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to update password.'};
    }
  }
}
