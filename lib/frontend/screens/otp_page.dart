import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

import 'package:subscription_rooks_app/frontend/screens/customer_login_pages.dart';
import 'package:subscription_rooks_app/frontend/screens/phone_number_page.dart';
// import 'package:subscription_rooks_app/frontend/screens/customer_Dashboard_page.dart';

class OTPPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OTPPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && _otpControllers[i].text.isEmpty) {
          if (i > 0) {
            _focusNodes[i - 1].requestFocus();
          }
        }
      });
    }
  }

  void _onOTPChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto verify when all fields are filled
    if (_isAllFieldsFilled()) {
      _verifyOTP();
    }
  }

  bool _isAllFieldsFilled() {
    for (var controller in _otpControllers) {
      if (controller.text.isEmpty) return false;
    }
    return true;
  }

  String _getOTP() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _saveOTPVerificationStatus() async {
    try {
      // Use widget.phoneNumber directly to check against existing collection
      String phoneNumberToQuery = widget.phoneNumber.trim();

      print('Looking for existing customer with phone: $phoneNumberToQuery');

      // Query to find the customer record by phone number in CustomerLoginDetails collection
      QuerySnapshot querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: phoneNumberToQuery)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Document exists - Update it with otpstatus
        String documentId = querySnapshot.docs.first.id;
        print('Found existing customer with ID: $documentId');

        await FirestoreService.instance
            .collection('CustomerLogindetails')
            .doc(documentId)
            .update({
              'otpstatus': 'verified',
              'verificationTime': DateTime.now(),
              'lastVerified': FieldValue.serverTimestamp(),
            });

        print(
          '✓ OTP verification status updated successfully for document: $documentId',
        );
      } else {
        print(
          '⚠ No existing customer record found with phone number: $phoneNumberToQuery',
        );
      }
    } catch (e) {
      print('Error saving OTP verification status: $e');
    }
  }

  Future<bool> _verifyPhoneNumberAndStatus() async {
    try {
      // Use widget.phoneNumber for verification
      String phoneNumberToQuery = widget.phoneNumber.trim();

      // Query the CustomerLoginDetails collection by phone number
      QuerySnapshot querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: phoneNumberToQuery)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;

        // Check if otpstatus is verified
        String otpStatus = data['otpstatus'] ?? '';

        if (otpStatus == 'verified') {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error verifying phone and status: $e');
      return false;
    }
  }

  void _verifyOTP() async {
    if (!_isAllFieldsFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    String smsCode = _getOTP();

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _loading = false);

      // Save OTP verification status to Firestore
      await _saveOTPVerificationStatus();

      // Check if phone number matches and OTP status is verified
      bool isVerified = await _verifyPhoneNumberAndStatus();

      // Navigate based on verification status
      if (isVerified) {
        // Navigate to PhoneNumberPage with login tab displayed
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PhoneNumberPage(initialTabIndex: 0), // 0 = Login tab
          ),
          (route) => false,
        );
      } else {
        // Navigate to CategoryScreen if not verified
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => CustomerTypePage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear all fields on error
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative elements
              // Background decorative elements removed for white theme
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.06,
                  vertical: MediaQuery.of(context).size.height * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.1),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        splashRadius: 20,
                      ),
                    ),

                    SizedBox(height: 30),

                    // Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify OTP',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.color,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code sent to',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '+91 ${widget.phoneNumber}',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 50),

                    // Glassmorphism Card for OTP
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width * 0.08,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // OTP Icon
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            height: MediaQuery.of(context).size.width * 0.2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).cardColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.sms_rounded,
                              size: MediaQuery.of(context).size.width * 0.1,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),

                          SizedBox(height: 32),

                          // OTP Input Fields
                          Text(
                            'Enter OTP Code',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.titleMedium?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),

                          SizedBox(height: 20),

                          // 6-digit OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return Flexible(
                                child: AspectRatio(
                                  aspectRatio: 0.8,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minWidth: 40,
                                      maxWidth: 60,
                                      minHeight: 50,
                                      maxHeight: 70,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white10
                                            : Theme.of(context).cardColor,
                                      ),
                                      onChanged: (value) =>
                                          _onOTPChanged(value, index),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          SizedBox(height: 40),

                          // Verify Button
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Theme.of(context).primaryColor,
                              boxShadow: _loading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5),
                                        blurRadius: 15,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                            ),
                            child: _loading
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  )
                                : Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _verifyOTP,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Verify OTP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.verified_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          SizedBox(height: 24),

                          // Resend OTP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  // Add resend OTP functionality here
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('OTP resent successfully!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 10),

                          // Auto verification info
                          Text(
                            'Auto-verification enabled',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),

                          SizedBox(height: 10),

                          // Success message preview
                          Text(
                            'Success! Redirecting to categories...',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
