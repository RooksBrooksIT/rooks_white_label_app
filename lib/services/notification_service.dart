import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'dart:io';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background work
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // If you want to show a notification manually for data-only messages (optional, since Cloud Functions sends notification payload)
  // define the plugin instance here if needed, but for now we rely on the system handling the notification payload.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> initialize() async {
    print("Initializing NotificationService...");
    // 1. Request permissions (Skip on Windows)
    if (!Platform.isWindows) {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      } else {
        print('User declined or has not accepted permission');
      }
    }

    if (Platform.isAndroid) {
      // Request Android 13+ notification permissions
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    }

    // 2. Setup High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }

    // 3. Initialize Local Notifications
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    print("Platform: ${Platform.operatingSystem}");

    final LinuxInitializationSettings linuxInitSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // Debug print for Windows settings
    print("Creating Windows Init Settings...");
    final WindowsInitializationSettings windowsInitSettings =
        WindowsInitializationSettings(
          appName: 'Subscription Rooks App',
          appUserModelId: 'com.rooks.customer_app',
          guid: '81941d4c-474c-4a37-88C4-954388837000',
        );
    print("Windows Init Settings created.");

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
      linux: linuxInitSettings,
      windows: windowsInitSettings,
    );

    try {
      print("Initializing Local Notifications Plugin...");
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
          print("Notification tapped: ${details.payload}");
        },
      );
      print("Local Notifications initialized successfully.");
    } catch (e) {
      print("Error initializing local notifications: $e");
    }

    // 4. Set up iOS Foreground Presentation Options, 5. Foreground handling, 6. App opened, 7. Get token
    // FCM is not supported on Windows, so we skip these steps
    if (!Platform.isWindows) {
      // 4. Set up iOS Foreground Presentation Options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Set up Foreground handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Foreground message received: ${message.notification?.title}");
        _showLocalNotification(message);
      });

      // 6. Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("App opened from notification: ${message.notification?.title}");
      });

      // 7. Get initial token
      try {
        String? token = await _fcm.getToken();
        print("FCM Token on init: $token");
      } catch (e) {
        print("Error getting FCM token on init: $e");
      }
    } else {
      print("Skipping FCM initialization on Windows (not supported).");
    }
  }

  /// General purpose notification method
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    print('Showing local notification: $title / $body');
    try {
      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        platformDetails,
        payload: data?.toString(),
      );
      print('Local notification displayed successfully');
    } catch (e) {
      print('Error displaying local notification: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // If notification payload is null (data-only message), try to get info from data
    String title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    String body = message.notification?.body ?? message.data['body'] ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformDetails,
      payload: message.data.toString(),
    );
  }

  Future<void> registerToken({
    required String role,
    required String userId,
    String email = '',
  }) async {
    try {
      if (Platform.isWindows) {
        print("Skipping FCM token registration on Windows (not supported).");
        return;
      }

      if (userId.isEmpty) {
        print("Skipping token registration: UserId is empty for role $role");
        return;
      }

      String? token = await _fcm.getToken();
      if (token == null) {
        print("FCM Token is null, cannot register.");
        return;
      }

      print("Registering FCM token for $role ($userId): $token");
      final docPath =
          FirestoreService.instance.collection('notifications_tokens').doc(role).collection('tokens').doc(userId).path;
      print("Full Firestore Path: $docPath");

      await FirestoreService.instance
          .collection('notifications_tokens')
          .doc(role)
          .collection('tokens')
          .doc(userId)
          .set({
            'token': token,
            'email': email,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': Platform.operatingSystem,
          }, SetOptions(merge: true))
          .then((_) => print("Token registered SUCCESSFULLY at $docPath"))
          .catchError((e) {
            print("Token registration FAILED: $e");
            return null;
          });

      print("Token registration initiated for $userId");

      _fcm.onTokenRefresh.listen((newToken) {
        print("FCM Token refreshed: $newToken");
        FirestoreService.instance
            .collection('notifications_tokens')
            .doc(role)
            .collection('tokens')
            .doc(userId)
            .update({
              'token': newToken,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      });
    } catch (e) {
      print("Error registering FCM token: $e");
    }
  }
}
