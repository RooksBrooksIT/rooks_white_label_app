import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_Dashboard_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isVerified = false;
  bool _loading = false;
  bool _resending = false;
  late User _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _checkEmailVerificationStatus();
  }

  Future<void> _checkEmailVerificationStatus() async {
    setState(() => _loading = true);
    await _user.reload();
    _user = FirebaseAuth.instance.currentUser!;
    setState(() {
      _isVerified = _user.emailVerified;
      _loading = false;
    });

    if (_isVerified) {
      // If verified, move to the dashboard
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryScreen(
              name: _user.displayName ?? "User",
              loggedInName: _user.displayName ?? "User",
              phoneNumber: '',
            ),
          ),
          (route) => false,
        );
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      setState(() => _resending = true);
      await _user.sendEmailVerification();
      setState(() => _resending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email resent to ${widget.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _resending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _loading
                ? CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.email_rounded,
                          color: Theme.of(context).primaryColor,
                          size: 60,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Text(
                        'Verify Your Email',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A verification link has been sent to:',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Check Verification Button
                      ElevatedButton.icon(
                        onPressed: _checkEmailVerificationStatus,
                        icon: Icon(
                          Icons.refresh,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: Text(
                          "Check Verification Status",
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend Button
                      ElevatedButton.icon(
                        onPressed: _resending ? null : _resendVerificationEmail,
                        icon: Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: _resending
                            ? Text(
                                "Sending...",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontFamily: 'Poppins',
                                ),
                              )
                            : Text(
                                "Resend Verification Email",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Status Message
                      Text(
                        _isVerified
                            ? 'Email Verified! Redirecting...'
                            : 'Waiting for email verification...',
                        style: TextStyle(
                          color: _isVerified
                              ? Colors.green
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
