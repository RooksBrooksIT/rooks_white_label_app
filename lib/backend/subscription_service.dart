import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// A service class responsible for handling subscription-related Firestore operations.
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sanitizes the username by converting it to lowercase and removing all spaces
  /// and special characters.
  String sanitizeUsername(String username) {
    // Convert to lowercase
    String sanitized = username.toLowerCase();
    // Remove all spaces and non-alphanumeric characters
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return sanitized;
  }

  /// Generates the dynamic username_date segment in the format: username_yyyyMMdd
  String generateUsernameDateSegment(String username) {
    String sanitized = sanitizeUsername(username);
    String datePart = DateFormat('yyyyMMdd').format(DateTime.now());
    return '${sanitized}_$datePart';
  }

  /// Saves subscription data to Firestore using a dynamic path structure:
  /// default_db -> main -> {appName} -> {username_date} -> {autoDocumentId}
  ///
  /// Note: The 'default_db' part is usually handled by the Firestore instance configuration
  /// if you are using multiple databases, but for standard implementations,
  /// it starts from the 'main' collection.
  Future<void> saveSubscription({
    required String appName,
    required String username,
    required String email,
    required String phone,
  }) async {
    try {
      String usernameDate = generateUsernameDateSegment(username);

      // Path: main (coll) -> {appName} (doc) -> {username_date} (coll) -> {autoId} (doc)
      await _firestore
          .collection('main')
          .doc(appName)
          .collection(usernameDate)
          .add({
            'username': username,
            'email': email,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error saving subscription: $e');
      rethrow;
    }
  }
}
