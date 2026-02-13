import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:subscription_rooks_app/firebase_options.dart';
import 'package:subscription_rooks_app/frontend/screens/splash_screen.dart';
import 'package:subscription_rooks_app/services/stripe_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Notification Service
  await NotificationService.instance.initialize();

  // Initialize Auth
  await AuthStateService.instance.init();

  // Initialize Theme
  await ThemeService.instance.init();

  // Initialize Stripe
  await StripeService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter App',
          theme: ThemeService.instance.themeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}
