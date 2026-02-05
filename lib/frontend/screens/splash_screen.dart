import 'dart:async';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/role_selection_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/backend/screens/admin_login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final bool isAdminLoggedIn = await AdminLoginBackend.checkLoginStatus();

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Widget target;
      if (isAdminLoggedIn) {
        target = const admindashboard();
      } else {
        target = const RoleSelectionScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;
    final isDarkBackground = theme.backgroundColor.computeLuminance() < 0.5;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              theme.backgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Support for dynamic logo
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: theme.logoUrl != null && theme.logoUrl!.isNotEmpty
                        ? Image.network(
                            theme.logoUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultLogo(),
                          )
                        : _buildDefaultLogo(),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Dynamic App Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  theme.appName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkBackground ? Colors.white : Colors.black87,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color:
                        (isDarkBackground ? Colors.white : theme.primaryColor)
                            .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 100,
      height: 100,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.rocket_launch_rounded,
        size: 60,
        color: ThemeService.instance.primaryColor,
      ),
    );
  }
}
