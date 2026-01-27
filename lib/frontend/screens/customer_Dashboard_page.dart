import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_home_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_service_tracker_page.dart';
import 'package:subscription_rooks_app/frontend/screens/phone_number_page.dart';
import 'package:subscription_rooks_app/backend/screens/customer_Dashboard_page.dart';
// import 'package:service_app/cus_login_Main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class CategoryScreen extends StatefulWidget {
  final String name;
  final String loggedInName;
  final String phoneNumber;
  const CategoryScreen({
    super.key,
    required this.name,
    required this.loggedInName,
    required this.phoneNumber,
  });

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String loggedInName = "Guest";
  String userPhoneNumber = "";

  @override
  void initState() {
    super.initState();
    _initializeLoggedInName();
    _initializeFirebaseAndMessaging();
  }

  Future<void> _initializeLoggedInName() async {
    final userInfo = await CustomerDashboardBackend.getStoredUserInfo(
      widget.loggedInName,
      widget.phoneNumber,
    );
    setState(() {
      loggedInName = userInfo['userName'] ?? "Guest";
      userPhoneNumber = userInfo['phoneNumber'] ?? "";
    });
  }

  Future<void> _initializeFirebaseAndMessaging() async {
    // await Firebase.initializeApp(); // Already initialized in main

    // Setup local notifications
    await _setupLocalNotifications();

    // Request permission for notifications
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
      _setupFCMListeners();
      await _getAndSaveToken();
    } else {
      print('Notification permission declined');
    }
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped from background');
      _handleNotificationTap(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print('Notification caused app launch');
        _handleNotificationTap(message);
      }
    });
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null) {
          _navigateToDetails(payload);
        }
      },
    );
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ticket_status_channel',
            'Ticket Status Notifications',
            channelDescription: 'Notifications about ticket status updates',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data['bookingId'], // Use bookingId as payload
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final String? bookingId = message.data['bookingId'];
    if (bookingId != null) {
      _navigateToDetails(bookingId);
    }
  }

  void _navigateToDetails(String bookingId) {
    print('Navigating to details for bookingId: $bookingId');
  }

  Future<void> _getAndSaveToken() async {
    await CustomerDashboardBackend.saveFcmToken(userPhoneNumber);
  }

  // Handle Android back button press
  Future<bool> _onWillPop() async {
    // Show an exit confirmation dialog on first back press.
    // If the user presses the device back button again while the dialog
    // is open, the dialog's WillPopScope will call SystemNavigator.pop().
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async {
            // Device back pressed while dialog open -> exit app
            SystemNavigator.pop();
            return true;
          },
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.exit_to_app, color: Theme.of(context).primaryColor),
                const SizedBox(width: 10),
                Text(
                  "Exit App",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Are you sure you want to exit the app?",
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Explicit exit via button
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Exit",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Prevent the default pop because we either exit explicitly or stay.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(appBar: _buildAppBar(), body: _buildBody()),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      // Removed the leading back button
      automaticallyImplyLeading: false, // This prevents the back button
      title: Text(
        ThemeService.instance.appName,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      iconTheme: IconThemeData(
        color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
      ),
      elevation: 0,
      toolbarHeight: 80,
      actions: [
        // Logout Button
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.logout,
              color:
                  Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
              size: 22,
            ),
            onPressed: () => _showLogoutConfirmationDialog(context),
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loggedInName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Text(
                //   userPhoneNumber,
                //   style: const TextStyle(
                //     fontSize: 28,
                //     fontWeight: FontWeight.bold,
                //     color: Color(0xFF0B3470),
                //     letterSpacing: 0.5,
                //   ),
                // ),
                // const SizedBox(height: 16),
                Text(
                  'Manage your service tickets efficiently',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Main Action Cards - Two buttons in a row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.confirmation_number,
                    title: 'Create Tickets',
                    subtitle: 'View and manage your service requests',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerHomePage(
                            customerName: loggedInName,
                            loggedInName: '',
                            name: '',
                            categoryName: '',
                            customerId: '',
                            mobileNumber: userPhoneNumber,
                          ),
                        ),
                      );
                    },
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.announcement,
                    title: 'Track My Tickets',
                    subtitle: 'Latest announcements and news',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminUpdatesPage(
                            name: loggedInName,
                            mobileNumber: userPhoneNumber,
                          ),
                        ),
                      );
                    },
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Additional Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.notifications_active,
                    title: 'Real-time Updates',
                    subtitle: 'Get instant notifications',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.support_agent,
                    title: 'Quick Support',
                    subtitle: '24/7 assistance',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: color.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          // gradient: LinearGradient(
          //   colors: [color, _darkenColor(color, 0.2)],
          //   begin: Alignment.topLeft,
          //   end: Alignment.bottomRight,
          // ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).primaryColor.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              Text(
                "Logout",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to logout?",
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await CustomerDashboardBackend.logout();

    if (!mounted) return;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logged out successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );

    // Navigate to login page
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PhoneNumberPage()),
      (route) => false,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(
    MaterialApp(
      home: prefs.getBool('isLoggedIn') == true
          ? CategoryScreen(
              name: prefs.getString('userName') ?? 'Guest',
              loggedInName: prefs.getString('userName') ?? 'Guest',
              phoneNumber: '',
            )
          : PhoneNumberPage(),
    ),
  );
}
