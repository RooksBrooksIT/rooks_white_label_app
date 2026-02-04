import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminDashboardBackend {
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
        .collection('Engineer_details')
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
