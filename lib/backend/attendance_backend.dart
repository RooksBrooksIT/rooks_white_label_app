import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AttendanceBackend {
  static CollectionReference get _attendanceRef =>
      FirestoreService.instance.collection('EngineerAttendance');
  static CollectionReference get _engineerRef =>
      FirestoreService.instance.collection('EngineerLogin');

  /// Fetches the list of engineers from the EngineerLogin collection.
  static Future<List<Map<String, dynamic>>> getEngineers() async {
    try {
      final snapshot = await _engineerRef.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'username': data['Username'] ?? '', 'id': doc.id};
      }).toList();
    } catch (e) {
      print('Error fetching engineers: $e');
      return [];
    }
  }

  static final List<String> _monthNames = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  static String _getMonthlyDocId(String username, DateTime date) {
    String month = _monthNames[date.month - 1];
    return "${username.toLowerCase()}_${month}_${date.year}";
  }

  static String _getDateKey(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  /// Marks attendance for a specific engineer on a specific date.
  static Future<void> markAttendance({
    required String engineerUsername,
    required DateTime date,
    required String status,
    required String markedBy,
    String remarks = '',
  }) async {
    try {
      final docId = _getMonthlyDocId(engineerUsername, date);
      final dateKey = _getDateKey(date);
      String month = _monthNames[date.month - 1];

      final data = {
        dateKey: {
          'engineerUsername': engineerUsername.toLowerCase(),
          'status': status,
          'markedBy': markedBy,
          'remarks': remarks,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'monthYear': "${month}_${date.year}", // For easier querying
        'engineerUsername': engineerUsername.toLowerCase(),
      };

      await _attendanceRef.doc(docId).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }

  /// Gets attendance records for all engineers on a specific date.
  static Stream<QuerySnapshot> getAttendanceForDate(DateTime date) {
    String month = _monthNames[date.month - 1];
    String monthYear = "${month}_${date.year}";

    return _attendanceRef.where('monthYear', isEqualTo: monthYear).snapshots();
  }

  /// Gets historical attendance records for a specific engineer.
  static Stream<QuerySnapshot> getEngineerAttendanceHistory(
    String engineerUsername, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    // For simplicity, we fetch all monthly documents for this engineer.
    // Filtering for date range should happen in the flattened data.
    return _attendanceRef
        .where('engineerUsername', isEqualTo: engineerUsername.toLowerCase())
        .snapshots();
  }

  /// Fetches all attendance records (for admin reports).
  static Stream<QuerySnapshot> getAllAttendanceHistory() {
    return _attendanceRef
        .snapshots(); // Might need logic change if reports depend on date field
  }

  /// Deletes attendance record for a specific engineer on a specific date.
  static Future<void> deleteAttendance({
    required String engineerUsername,
    required DateTime date,
  }) async {
    try {
      final docId = _getMonthlyDocId(engineerUsername, date);
      final dateKey = _getDateKey(date);

      await _attendanceRef.doc(docId).update({dateKey: FieldValue.delete()});
    } catch (e) {
      print('Error deleting attendance: $e');
      rethrow;
    }
  }
}
