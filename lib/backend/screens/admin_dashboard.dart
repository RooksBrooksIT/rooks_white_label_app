import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminDashboardBackend {
  static Stream<int> getEngineerUpdateCountStream() {
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
