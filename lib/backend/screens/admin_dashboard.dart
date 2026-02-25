import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminDashboardBackend {
  static Future<Map<String, String>> getAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'name': 'Admin', 'email': ''};

    try {
      final doc = await FirestoreService.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name'] ?? 'Admin',
          'email': data['email'] ?? user.email ?? '',
        };
      }
    } catch (e) {
      print('Error fetching admin profile: $e');
    }
    return {'name': 'Admin', 'email': user.email ?? ''};
  }

  static Future<String> getReferralCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '';

      final code = await FirestoreService.instance.getReferralCodeForAdmin(
        user.uid,
      );

      return code ?? '';
    } catch (e) {
      print('Error fetching referral code: $e');
    }
    return ''; // Return empty if not found
  }

  static Stream<int> getEngineerUpdateCountStream() {
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getTotalCustomersStream() {
    return FirestoreService.instance
        .collection('AMC_user')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getActiveEngineersStream() {
    return FirestoreService.instance
        .collection('EngineerLogin') // Use the core login collection
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getTotalEngineersStream() {
    return FirestoreService.instance
        .collection('EngineerLogin')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getPendingTicketsStream() {
    // Assuming 'status' is a field in the tickets collection
    // This will count docs across multiple ticket collections if needed,
    // or just one depending on how the app is structured.
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.where((doc) {
            final data = doc.data();
            return data['status'] == 'pending' || data['status'] == 'open';
          }).length,
        );
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
