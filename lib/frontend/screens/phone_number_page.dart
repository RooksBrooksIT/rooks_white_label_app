import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/backend/screens/phone_number_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_Dashboard_page.dart';

class PhoneNumberPage extends StatefulWidget {
  final int initialTabIndex;

  const PhoneNumberPage({super.key, this.initialTabIndex = 0});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKeySignup = GlobalKey<FormState>();
  final _formKeyLogin = GlobalKey<FormState>();

  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupPhoneController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  final TextEditingController _signupConfirmPasswordController =
      TextEditingController();

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  bool _loadingSignup = false;
  bool _loadingLogin = false;
  bool _emailAutoFilled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // Listen for phone number changes to auto-fill email
    _loginPhoneController.addListener(_autoFillEmail);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signupNameController.dispose();
    _signupPhoneController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  // Auto-fill email based on phone number
  void _autoFillEmail() async {
    String phoneNumber = _loginPhoneController.text.trim();

    if (phoneNumber.length == 10 && !_emailAutoFilled) {
      String? email = await PhoneNumberPageBackend.autoFillEmail(phoneNumber);
      if (email != null) {
        setState(() {
          _loginEmailController.text = email;
          _emailAutoFilled = true;
        });
      } else {
        setState(() {
          _loginEmailController.clear();
          _emailAutoFilled = false;
        });
      }
    } else if (phoneNumber.length != 10) {
      setState(() {
        _loginEmailController.clear();
        _emailAutoFilled = false;
      });
    }
  }

  // 🔹 Signup with Phone Number Validation
  void _signup() async {
    if (!_formKeySignup.currentState!.validate()) return;

    String name = _signupNameController.text.trim();
    String phone = _signupPhoneController.text.trim();
    String email = _signupEmailController.text.trim();
    String password = _signupPasswordController.text.trim();
    String confirmPassword = _signupConfirmPasswordController.text.trim();

    // Check if passwords match
    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _loadingSignup = true);

    final result = await PhoneNumberPageBackend.signup(
      name: name,
      phone: phone,
      email: email,
      password: password,
    );

    setState(() => _loadingSignup = false);

    if (result['success']) {
      _showSnackBar('Account created successfully! You can now login.');
      _signupNameController.clear();
      _signupPhoneController.clear();
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupConfirmPasswordController.clear();
      _tabController.animateTo(0);
    } else {
      _showSnackBar(result['message'], isError: true);
    }
  }

  // 🔹 Login with Phone Number + Password
  void _login() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    String phoneNumber = _loginPhoneController.text.trim();
    String password = _loginPasswordController.text.trim();

    setState(() => _loadingLogin = true);

    final result = await PhoneNumberPageBackend.login(phoneNumber, password);

    setState(() => _loadingLogin = false);

    if (result['success']) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryScreen(
            name: result['userName'],
            loggedInName: result['userName'],
            phoneNumber: result['userPhone'],
          ),
        ),
      );
    } else {
      _showSnackBar(result['message'], isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
      ),
    );
  }

  // 🔹 Forgot Password Functionality
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot Password'),
        content: const Text('Contact Admin to change the password'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).primaryColor,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI SECTION ---------------- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Login or create an account',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 18,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              TabBar(
                                controller: _tabController,
                                indicatorColor: Theme.of(context).primaryColor,
                                labelColor: Theme.of(context).primaryColor,
                                unselectedLabelColor: Theme.of(
                                  context,
                                ).hintColor,
                                labelStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                ),
                                tabs: const [
                                  Tab(text: "Login"),
                                  Tab(text: "Signup"),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildLoginTab(),
                                    _buildSignupTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // 🔹 Reusable Input Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    String? prefixText,
    required List<TextInputFormatter> inputFormatters,
    required String? Function(String?) validator,
    required TextInputType keyboardType,
    bool obscureText = false,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        readOnly: readOnly,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: readOnly
              ? Theme.of(context).disabledColor
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          prefixText: prefixText,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          counterText: '',
        ),
      ),
    );
  }

  // 🔹 Login Tab
  Widget _buildLoginTab() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeyLogin,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildTextField(
              controller: _loginPhoneController,
              label: "Phone Number",
              icon: Icons.phone_iphone_rounded,
              maxLength: 10,
              prefixText: '+91 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value == null || value.length != 10) {
                  return "Enter valid phone number";
                }
                return null;
              },
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _loginEmailController,
              label: "Email (Auto-filled)",
              icon: Icons.email_outlined,
              inputFormatters: [],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Email will auto-fill when phone number is entered";
                }
                return null;
              },
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
            ),
            _buildTextField(
              controller: _loginPasswordController,
              label: "Password",
              icon: Icons.lock_outline_rounded,
              inputFormatters: [],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Enter your password";
                }
                return null;
              },
              keyboardType: TextInputType.text,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            // Forgot Password Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadingLogin ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _loadingLogin
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Signup Tab
  Widget _buildSignupTab() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeySignup,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTextField(
              controller: _signupNameController,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return "Enter your name";
                return null;
              },
              keyboardType: TextInputType.text,
            ),
            _buildTextField(
              controller: _signupPhoneController,
              label: "Phone Number",
              icon: Icons.phone_iphone_rounded,
              maxLength: 10,
              prefixText: '+91 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value == null || value.length != 10) {
                  return "Enter valid phone number";
                }
                return null;
              },
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _signupEmailController,
              label: "Email Address",
              icon: Icons.email_outlined,
              inputFormatters: [],
              validator: (value) {
                if (value == null || value.isEmpty) return "Enter your email";
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return "Enter valid email";
                }
                return null;
              },
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              controller: _signupPasswordController,
              label: "Password",
              icon: Icons.lock_outline_rounded,
              inputFormatters: [],
              validator: (value) {
                if (value == null || value.length < 6) {
                  return "Password must be at least 6 characters";
                }
                return null;
              },
              keyboardType: TextInputType.text,
              obscureText: true,
            ),
            _buildTextField(
              controller: _signupConfirmPasswordController,
              label: "Confirm Password",
              icon: Icons.lock_outline_rounded,
              inputFormatters: [],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please confirm your password";
                }
                return null;
              },
              keyboardType: TextInputType.text,
              obscureText: true,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _loadingSignup ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _loadingSignup
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Forgot Password Dialog
class ForgotPasswordDialog extends StatefulWidget {
  final String? initialPhone;

  const ForgotPasswordDialog({super.key, this.initialPhone});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final TextEditingController _existingPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _altNewPasswordController =
      TextEditingController();
  final TextEditingController _altConfirmPasswordController =
      TextEditingController();

  bool _isPrimaryMethod = true;
  bool _isNewPasswordEnabled = false;
  bool _isAltMethodEnabled = false;
  bool _loading = false;
  String _currentUserPhone = '';

  // Real-time validation state
  Timer? _debounceExisting;
  Timer? _debounceAlt;
  String _existingStatusMessage = '';
  bool _isExistingPasswordValid = false;
  String _altStatusMessage = '';
  bool _isAltVerified = false;

  // Password visibility toggles
  bool _showExistingPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _showAltNewPassword = false;
  bool _showAltConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone if passed from parent
    _currentUserPhone = widget.initialPhone ?? '';

    // Add listeners for real-time checks
    _existingPasswordController.addListener(_onExistingPasswordChanged);
    _usernameController.addListener(_onAltFieldsChanged);
    _phoneController.addListener(_onAltFieldsChanged);
  }

  @override
  void dispose() {
    _debounceExisting?.cancel();
    _debounceAlt?.cancel();
    _existingPasswordController.removeListener(_onExistingPasswordChanged);
    _usernameController.removeListener(_onAltFieldsChanged);
    _phoneController.removeListener(_onAltFieldsChanged);

    _existingPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _altNewPasswordController.dispose();
    _altConfirmPasswordController.dispose();
    super.dispose();
  }

  // Check existing password
  void _checkExistingPassword() async {
    if (_currentUserPhone.isEmpty) return;

    setState(() => _loading = true);

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: _currentUserPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var userData = querySnapshot.docs.first.data();
        String storedPassword = userData['password'];

        if (_existingPasswordController.text == storedPassword) {
          setState(() {
            _isNewPasswordEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Password verified. You can now set new password.',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Incorrect existing password.'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }

    setState(() => _loading = false);
  }

  // Real-time / auto-check existing password (debounced)
  void _onExistingPasswordChanged() {
    if (_debounceExisting?.isActive ?? false) _debounceExisting!.cancel();
    _debounceExisting = Timer(const Duration(milliseconds: 500), () {
      _checkExistingPasswordAuto();
    });
  }

  Future<void> _checkExistingPasswordAuto() async {
    // Clear status when field empty
    if (_existingPasswordController.text.isEmpty) {
      setState(() {
        _existingStatusMessage = '';
        _isExistingPasswordValid = false;
        _isNewPasswordEnabled = false;
      });
      return;
    }

    if (_currentUserPhone.isEmpty) {
      setState(() {
        _existingStatusMessage =
            'No phone number provided. Enter phone on login page.';
        _isExistingPasswordValid = false;
        _isNewPasswordEnabled = false;
      });
      return;
    }

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: _currentUserPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var userData = querySnapshot.docs.first.data();
        String storedPassword = userData['password'];

        if (_existingPasswordController.text == storedPassword) {
          setState(() {
            _existingStatusMessage = 'Password verified ✅';
            _isExistingPasswordValid = true;
            _isNewPasswordEnabled = true;
          });
        } else {
          setState(() {
            _existingStatusMessage = 'Incorrect password';
            _isExistingPasswordValid = false;
            _isNewPasswordEnabled = false;
          });
        }
      } else {
        setState(() {
          _existingStatusMessage = 'No account found for provided phone';
          _isExistingPasswordValid = false;
          _isNewPasswordEnabled = false;
        });
      }
    } catch (e) {
      setState(() {
        _existingStatusMessage = 'Error checking password';
      });
    }
  }

  // Real-time / auto-check for alternative method (debounced)
  void _onAltFieldsChanged() {
    if (_debounceAlt?.isActive ?? false) _debounceAlt!.cancel();
    _debounceAlt = Timer(const Duration(milliseconds: 500), () {
      _verifyUsernameAndPhoneAuto();
    });
  }

  Future<void> _verifyUsernameAndPhoneAuto() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    if (username.isEmpty || phone.length != 10) {
      setState(() {
        _altStatusMessage = '';
        _isAltVerified = false;
        _isAltMethodEnabled = false;
      });
      return;
    }

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('name', isEqualTo: username)
          .where('phonenumber', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _altStatusMessage = 'Verification successful ✅';
          _isAltVerified = true;
          _isAltMethodEnabled = true;
          _currentUserPhone = phone;
        });
      } else {
        setState(() {
          _altStatusMessage = 'Username and phone do not match';
          _isAltVerified = false;
          _isAltMethodEnabled = false;
        });
      }
    } catch (e) {
      setState(() {
        _altStatusMessage = 'Error verifying account';
        _isAltVerified = false;
        _isAltMethodEnabled = false;
      });
    }
  }

  // Update password with primary method
  void _updatePassword() async {
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New passwords do not match.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password must be at least 6 characters.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: _currentUserPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        String docId = querySnapshot.docs.first.id;
        await FirestoreService.instance
            .collection('CustomerLogindetails')
            .doc(docId)
            .update({
              'password': _newPasswordController.text,
              'updatedAt': DateTime.now().toIso8601String(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating password: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }

    setState(() => _loading = false);
  }

  // Verify username and phone for alternative method
  void _verifyUsernameAndPhone() async {
    if (_usernameController.text.isEmpty ||
        _phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter valid username and phone number.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('name', isEqualTo: _usernameController.text.trim())
          .where('phonenumber', isEqualTo: _phoneController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _isAltMethodEnabled = true;
          _currentUserPhone = _phoneController.text.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Verification successful. You can now set new password.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Username and phone number do not match our records.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }

    setState(() => _loading = false);
  }

  // Update password with alternative method
  void _updatePasswordAlt() async {
    if (_altNewPasswordController.text != _altConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New passwords do not match.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (_altNewPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password must be at least 6 characters.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      var querySnapshot = await FirestoreService.instance
          .collection('CustomerLogindetails')
          .where('phonenumber', isEqualTo: _currentUserPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        String docId = querySnapshot.docs.first.id;
        await FirestoreService.instance
            .collection('CustomerLogindetails')
            .doc(docId)
            .update({
              'password': _altNewPasswordController.text,
              'updatedAt': DateTime.now().toIso8601String(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating password: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Forgot Password',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Method Toggle
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isPrimaryMethod
                          ? null
                          : () => setState(() => _isPrimaryMethod = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPrimaryMethod
                            ? const Color(0xFF1E3C72)
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Primary Method',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isPrimaryMethod
                          ? () => setState(() => _isPrimaryMethod = false)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isPrimaryMethod
                            ? const Color(0xFF1E3C72)
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Alternative',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isPrimaryMethod) ...[
                // Primary Method - Phone Number
                const Text(
                  'Enter your phone number and existing password:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: TextEditingController(text: _currentUserPhone),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(() {
                      _currentUserPhone = value.trim();
                      _existingStatusMessage = '';
                      _isExistingPasswordValid = false;
                      _isNewPasswordEnabled = false;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 15),
                // Primary Method - Existing Password
                const Text(
                  'Enter your existing password:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _existingPasswordController,
                  obscureText: !_showExistingPassword,
                  decoration: InputDecoration(
                    labelText: 'Existing Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showExistingPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: const Color(0xFF1E3C72),
                      ),
                      onPressed: () {
                        setState(() {
                          _showExistingPassword = !_showExistingPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_existingStatusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _existingStatusMessage,
                      style: TextStyle(
                        color: _isExistingPasswordValid
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 7),
                ElevatedButton(
                  onPressed: _loading ? null : _checkExistingPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Password'),
                ),
                const SizedBox(height: 20),

                // Primary Method - New Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  enabled: _isNewPasswordEnabled,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: const Color(0xFF1E3C72),
                      ),
                      onPressed: () {
                        setState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _confirmNewPasswordController,
                  obscureText: !_showConfirmPassword,
                  enabled: _isNewPasswordEnabled,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: const Color(0xFF1E3C72),
                      ),
                      onPressed: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isNewPasswordEnabled && !_loading
                      ? _updatePassword
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Password'),
                ),
              ] else ...[
                // Alternative Method - Username and Phone
                const Text(
                  'Enter your username and phone number:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                if (_altStatusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _altStatusMessage,
                      style: TextStyle(
                        color: _isAltVerified
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 7),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyUsernameAndPhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Account'),
                ),
                const SizedBox(height: 20),

                // Alternative Method - New Password
                if (_isAltMethodEnabled) ...[
                  const Text(
                    'Set your new password:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _altNewPasswordController,
                    obscureText: !_showAltNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showAltNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFF1E3C72),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAltNewPassword = !_showAltNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _altConfirmPasswordController,
                    obscureText: !_showAltConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showAltConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFF1E3C72),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAltConfirmPassword = !_showAltConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _updatePasswordAlt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Password'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
