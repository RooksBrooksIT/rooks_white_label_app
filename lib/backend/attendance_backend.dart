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

  /// Marks attendance for a specific engineer on a specific date.
  static Future<void> markAttendance({
    required String engineerUsername,
    required DateTime date,
    required String status,
    required String markedBy,
    String remarks = '',
  }) async {
    try {
      final dateStr =
          "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
      final docId = "${engineerUsername.toLowerCase()}_$dateStr";

      final startOfDay = DateTime(date.year, date.month, date.day);

      final data = {
        'engineerUsername': engineerUsername.toLowerCase(),
        'date': Timestamp.fromDate(startOfDay),
        'status': status,
        'markedBy': markedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'remarks': remarks,
      };

      await _attendanceRef.doc(docId).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }

  /// Gets attendance records for all engineers on a specific date.
  static Stream<QuerySnapshot> getAttendanceForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    return _attendanceRef
        .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots();
  }

  /// Gets historical attendance records for a specific engineer.
  static Stream<QuerySnapshot> getEngineerAttendanceHistory(
    String engineerUsername, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    Query query = _attendanceRef.where(
      'engineerUsername',
      isEqualTo: engineerUsername.toLowerCase(),
    );

    if (fromDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(fromDate.year, fromDate.month, fromDate.day),
        ),
      );
    }
    if (toDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(
          DateTime(toDate.year, toDate.month, toDate.day),
        ),
      );
    }

    return query.orderBy('date', descending: true).snapshots();
  }

  /// Fetches all attendance records (for admin reports).
  static Stream<QuerySnapshot> getAllAttendanceHistory() {
    return _attendanceRef.orderBy('date', descending: true).snapshots();
  }
}
