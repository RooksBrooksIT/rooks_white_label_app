import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class PhoneNumberPageBackend {
  static Future<String?> autoFillEmail(String phoneNumber) async {
    if (phoneNumber.length == 10) {
      try {
        var querySnapshot = await FirestoreService.instance
            .collection('CustomerLogindetails')
            .where('phonenumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return querySnapshot.docs.first['email'];
        }
      } catch (e) {
        print('Error auto-filling email: $e');
      }
    }
    return null;
  }

  static Future<String> generateCustomId() async {
    var querySnapshot = await FirestoreService.instance
        .collection('CustomerLogindetails')
        .orderBy('id', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 'CR001';
    } else {
      String lastId = querySnapshot.docs.first['id'];
      int lastNumber = int.tryParse(lastId.replaceAll('CR', '')) ?? 0;
      int newNumber = lastNumber + 1;
      return 'CR${newNumber.toString().padLeft(3, '0')}';
    }
  }

  static Future<bool> checkPhoneNumberExists(String phoneNumber) async {
    var querySnapshot = await FirestoreService.instance
        .collection('CustomerLogindetails')
        .where('phonenumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  static Future<bool> checkEmailExists(String email) async {
    var querySnapshot = await FirestoreService.instance
        .collection('CustomerLogindetails')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      if (await checkPhoneNumberExists(phone)) {
        return {
          'success': false,
          'message': 'This phone number is already registered.',
        };
      }
      if (await checkEmailExists(email)) {
        return {
          'success': false,
          'message': 'This email is already registered.',
        };
      }

      String newId = await generateCustomId();

      await FirestoreService.instance
          .collection('CustomerLogindetails')
          .doc(newId)
          .set({
            'id': newId,
            'name': name,
            'phonenumber': phone,
            'email': email,
            'password': password,
            'createdAt': DateTime.now().toIso8601String(),
          });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Signup failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> login(
    String phoneNumber,
    String password,
  ) async {
    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'Phone number not found.'};
      }

      var userData = querySnapshot.docs.first.data();
      if (password == userData['password']) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userName', userData['name']);
        await prefs.setString('phoneNumber', userData['phonenumber']);
        return {
          'success': true,
          'userName': userData['name'],
          'userPhone': userData['phonenumber'],
        };
      } else {
        return {'success': false, 'message': 'Incorrect password.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }
}
