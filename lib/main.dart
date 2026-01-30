import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:subscription_rooks_app/firebase_options.dart';
import 'package:subscription_rooks_app/frontend/screens/auth_selection_screen.dart';
import 'package:subscription_rooks_app/subscription/welcome_screen.dart';
import 'package:subscription_rooks_app/services/stripe_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Theme
  await ThemeService.instance.init();

  // Initialize Stripe
  // TODO: Make sure to set your publishable key in StripeService
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
          home: const AuthSelectionScreen(),
        );
      },
    );
  }
}
