import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AMCCreatePage extends StatefulWidget {
  const AMCCreatePage({super.key});

  @override
  State<AMCCreatePage> createState() => _AMCCreatePageState();
}

class _AMCCreatePageState extends State<AMCCreatePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;
  String? _emailError;
  String? _phoneError;

  // New variables for edit mode
  bool _isEditMode = false;
  String? _editingDocId;
  String? _originalEmail;
  String? _originalPhone;

  // Blue color scheme
  // Blue color scheme
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get lightBlue => Theme.of(context).primaryColorLight;
  Color get accentColor => Colors.green;
  Color get cardColor => Theme.of(context).cardColor;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get lightGrey => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[800]!
      : const Color(0xFFF5F5F5);
  final Color editModeColor = const Color(0xFFFF9800);

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _usernameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _obscurePassword = true;
      _obscureConfirmPassword = true;
      _emailError = null;
      _phoneError = null;
      _isEditMode = false;
      _editingDocId = null;
      _originalEmail = null;
      _originalPhone = null;
    });
  }

  void _loadAccountForEdit(Map<String, dynamic> data, String docId) {
    setState(() {
      _isEditMode = true;
      _editingDocId = docId;
      _usernameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['Phone Number'] ?? '';
      _originalEmail = data['email'] ?? '';
      _originalPhone = data['Phone Number'] ?? '';
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    // Close the drawer
    Navigator.of(context).pop();

    // Scroll to top
    Scrollable.ensureVisible(_formKey.currentContext!);
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<String?> _validateEmailUnique(String? value) async {
    // Skip validation if we're in edit mode and email hasn't changed
    if (_isEditMode && value == _originalEmail) {
      setState(() {
        _emailError = null;
      });
      return null;
    }

    final basicValidation = _validateEmail(value);
    if (basicValidation != null) {
      setState(() {
        _emailError = null;
      });
      return basicValidation;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });

    try {
      final emailExists = await _checkEmailExists(value!);
      if (emailExists) {
        setState(() {
          _emailError = 'This email is already registered';
        });
        return _emailError;
      }
      setState(() {
        _emailError = null;
      });
      return null;
    } catch (e) {
      setState(() {
        _emailError = 'Error checking email availability';
      });
      return _emailError;
    } finally {
      setState(() {
        _isCheckingEmail = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<String?> _validatePhoneNumberUnique(String? value) async {
    // Skip validation if we're in edit mode and phone hasn't changed
    if (_isEditMode && value == _originalPhone) {
      setState(() {
        _phoneError = null;
      });
      return null;
    }

    if (value == null || value.isEmpty) {
      setState(() {
        _phoneError = null;
      });
      return 'Please enter a phone number';
    }
    final numericRegex = RegExp(r'^\d{10}$');
    if (!numericRegex.hasMatch(value)) {
      setState(() {
        _phoneError = null;
      });
      return 'Phone number must be exactly 10 digits';
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneError = null;
    });

    try {
      final querySnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .where('Phone Number', isEqualTo: value)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _phoneError = 'This phone number is already registered';
        });
        return _phoneError;
      } else {
        setState(() {
          _phoneError = null;
        });
        return null;
      }
    } catch (e) {
      setState(() {
        _phoneError = 'Error checking phone number';
      });
      return _phoneError;
    } finally {
      setState(() {
        _isCheckingPhone = false;
      });
    }
  }

  String? _validatePhoneNumberBasic(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Phone number must be exactly 10 digits';
    }
    if (_phoneError != null) {
      return _phoneError;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    // In edit mode, password is optional
    if (_isEditMode && (value == null || value.isEmpty)) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    // In edit mode, if password is empty, confirmation should also be empty
    if (_isEditMode && _passwordController.text.isEmpty) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _deleteAccount(String docId, String userName) async {
    final bool? shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildDeleteConfirmationDialog(userName);
      },
    );

    if (shouldDelete == true) {
      await FirestoreService.instance
          .collection('AMC_user')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName account deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextInputAction textInputAction = TextInputAction.next,
    int? maxLength,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: primaryColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        filled: true,
        fillColor: enabled
            ? Theme.of(context).cardColor
            : Theme.of(context).disabledColor.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.02,
          horizontal: 16,
        ),
        labelStyle: TextStyle(color: primaryColor, fontSize: 16),
        floatingLabelStyle: TextStyle(color: primaryColor, fontSize: 16),
        hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      maxLength: maxLength,
      enabled: enabled,
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email address',
            prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
            suffixIcon: _isCheckingEmail
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  )
                : _emailError == null && _emailController.text.isNotEmpty
                ? Icon(Icons.check_circle, color: accentColor)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: errorColor, width: 2),
            ),
            filled: true,
            fillColor: _isEditMode
                ? Theme.of(context).disabledColor.withOpacity(0.1)
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : const Color(0xFFF5F5F5)),
            contentPadding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.02,
              horizontal: 16,
            ),
            labelStyle: TextStyle(color: primaryColor, fontSize: 16),
            floatingLabelStyle: TextStyle(color: primaryColor, fontSize: 16),
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 16,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            errorText: _emailError,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !_isEditMode, // Disable email editing in edit mode
          onChanged: (value) {
            if (_emailError != null && value.isNotEmpty) {
              setState(() {
                _emailError = null;
              });
            }
            if (value.isNotEmpty && !_isEditMode) {
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted && _emailController.text == value) {
                  _validateEmailUnique(value);
                }
              });
            }
          },
          validator: (value) {
            final basicValidation = _validateEmail(value);
            if (basicValidation != null) {
              return basicValidation;
            }
            return _emailError;
          },
        ),
        if (_isCheckingEmail)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Checking email availability...',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter 10-digit phone number',
            prefixIcon: Icon(Icons.phone, color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            errorText: _phoneError,
            suffixIcon: _isCheckingPhone
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  )
                : _phoneError == null && _phoneController.text.length == 10
                ? Icon(Icons.check_circle, color: accentColor)
                : null,
            filled: true,
            fillColor: _isEditMode
                ? Theme.of(context).disabledColor.withOpacity(0.1)
                : lightGrey,
          ),
          enabled: !_isEditMode, // Disable phone editing in edit mode
          validator: _validatePhoneNumberBasic,
          onChanged: (value) {
            if (_phoneError != null) {
              setState(() {
                _phoneError = null;
              });
            }
            if (value.length == 10 && !_isEditMode) {
              _validatePhoneNumberUnique(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      labelText: _isEditMode ? 'New Password (Optional)' : 'Password',
      hintText: _isEditMode
          ? 'Enter new password (leave empty to keep current)'
          : 'Enter your password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscurePassword,
      validator: _validatePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: primaryColor,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildTextField(
      controller: _confirmPasswordController,
      labelText: _isEditMode ? 'Confirm New Password' : 'Confirm Password',
      hintText: _isEditMode ? 'Confirm new password' : 'Confirm your password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscureConfirmPassword,
      validator: _validateConfirmPassword,
      textInputAction: TextInputAction.done,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
          color: primaryColor,
        ),
        onPressed: () {
          setState(() {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          });
        },
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final bool? shouldProceed = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return _buildConfirmationDialog();
        },
      );

      if (shouldProceed == true) {
        setState(() {
          _isLoading = true;
        });

        try {
          if (_isEditMode) {
            // Update existing account - only password can be changed
            final updateData = <String, dynamic>{};

            // Only update password if a new one is provided
            if (_passwordController.text.isNotEmpty) {
              updateData['password'] = _passwordController.text;
            }

            await FirestoreService.instance
                .collection('AMC_user')
                .doc(_editingDocId)
                .update(updateData);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account updated successfully!'),
                backgroundColor: accentColor,
              ),
            );

            _clearForm();
          } else {
            // Create new account (existing logic)
            final emailExists = await _checkEmailExists(_emailController.text);
            if (emailExists) {
              if (!mounted) return;
              setState(() {
                _emailError = 'This email is already registered';
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Email ${_emailController.text} is already registered!',
                  ),
                  backgroundColor: errorColor,
                ),
              );
              return;
            }

            final phoneQuery = await FirestoreService.instance
                .collection('AMC_user')
                .where('Phone Number', isEqualTo: _phoneController.text)
                .limit(1)
                .get();

            if (phoneQuery.docs.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _phoneError = 'This phone number is already registered';
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Phone number ${_phoneController.text} is already registered!',
                  ),
                  backgroundColor: errorColor,
                ),
              );
              return;
            }

            String newAmcId;
            try {
              final allDocs = await FirestoreService.instance
                  .collection('AMC_user')
                  .get();

              if (allDocs.docs.isEmpty) {
                newAmcId = 'AMC001';
              } else {
                int highestNumber = 0;
                for (var doc in allDocs.docs) {
                  final data = doc.data();
                  final id = data['Id'];
                  if (id != null && id.toString().startsWith('AMC')) {
                    try {
                      final numberPart = id.toString().substring(3);
                      final number = int.parse(numberPart);
                      if (number > highestNumber) {
                        highestNumber = number;
                      }
                    } catch (e) {
                      print('Skipping invalid ID format: $id');
                    }
                  }
                }
                newAmcId =
                    'AMC${(highestNumber + 1).toString().padLeft(3, '0')}';
              }
            } catch (e) {
              print('Error generating AMC ID: $e');
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final count = await FirestoreService.instance
                  .collection('AMC_user')
                  .get()
                  .then((snapshot) => snapshot.docs.length);
              newAmcId = 'AMC${(count + 1).toString().padLeft(3, '0')}';
            }

            await FirestoreService.instance
                .collection('AMC_user')
                .doc(newAmcId)
                .set({
                  'email': _emailController.text.toLowerCase().trim(),
                  'name': _usernameController.text,
                  'password': _passwordController.text,
                  'Phone Number': _phoneController.text,
                  'Id': newAmcId,
                  'createdAt': FieldValue.serverTimestamp(),
                });

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Account created successfully with ID: $newAmcId',
                ),
                backgroundColor: accentColor,
              ),
            );

            _clearForm();
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error ${_isEditMode ? 'updating' : 'creating'} account: $e',
              ),
              backgroundColor: errorColor,
            ),
          );
          print('Detailed error: $e');
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  Widget _buildConfirmationDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isEditMode ? Icons.edit_outlined : Icons.account_circle_outlined,
              size: 48,
              color: _isEditMode ? editModeColor : primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isEditMode
                  ? 'Confirm Account Update'
                  : 'Confirm Account Creation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isEditMode ? editModeColor : primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEditMode
                  ? 'Are you sure you want to update this account? Only password will be changed.'
                  : 'Are you sure you want to create this account?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      side: BorderSide(
                        color: _isEditMode ? editModeColor : primaryColor,
                      ),
                    ),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isEditMode ? editModeColor : primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: _isEditMode
                          ? editModeColor
                          : primaryColor,
                    ),
                    child: Text(
                      _isEditMode ? 'UPDATE' : 'CONFIRM',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmationDialog(String userName) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: errorColor),
            const SizedBox(height: 16),
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete $userName\'s account?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: errorColor,
                    ),
                    child: const Text(
                      'DELETE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Account' : 'Create Account'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _isEditMode ? editModeColor : primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt),
            onPressed: () {
              _scaffoldKey.currentState!.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        width: screenWidth * 0.8,
        child: Container(
          color: const Color(0xFF1E3C72),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: primaryColor,
                  child: Row(
                    children: const [
                      Icon(Icons.people_outline, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Account Management',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'All created accounts are listed below:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.instance
                        .collection('AMC_user')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No accounts found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final name = data['name'] ?? '';
                          final email =
                              data['email'] ?? (data['EmailId'] ?? '');
                          final amcId = data['Id'] ?? docs[index].id;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                name.isNotEmpty ? name : 'No Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(email.isNotEmpty ? email : 'No Email'),
                                  Text(
                                    'ID: $amcId',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: editModeColor,
                                    ),
                                    onPressed: () {
                                      _loadAccountForEdit(data, docs[index].id);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await _deleteAccount(
                                        docs[index].id,
                                        name,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (_isEditMode ? editModeColor : primaryColor).withOpacity(0.9),
              lightBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isEditMode ? editModeColor : primaryColor,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16.0 : 24.0,
                        vertical: isLandscape ? 8.0 : 16.0,
                      ),
                      child: Column(
                        children: [
                          if (!isLandscape)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isEditMode
                                    ? Icons.edit_outlined
                                    : Icons.person_add_alt_1,
                                size: screenWidth * 0.08,
                                color: _isEditMode
                                    ? editModeColor
                                    : primaryColor,
                              ),
                            ),
                          if (!isLandscape)
                            Text(
                              _isEditMode
                                  ? 'Edit Account'
                                  : 'Create New Account',
                              style: TextStyle(
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (!isLandscape) const SizedBox(height: 8),
                          if (!isLandscape)
                            Text(
                              _isEditMode
                                  ? 'You can only update the password for existing accounts'
                                  : 'Please fill in all the required information',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: screenWidth * 0.035,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          SizedBox(height: isLandscape ? 8 : 24),
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: cardColor,
                            child: Padding(
                              padding: EdgeInsets.all(
                                isSmallScreen ? 16.0 : 24.0,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_isEditMode)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: editModeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: editModeColor.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: editModeColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Edit Mode: Only password can be updated for existing accounts',
                                                style: TextStyle(
                                                  color: editModeColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_isEditMode) const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _usernameController,
                                      labelText: 'Username',
                                      hintText: 'Enter your username',
                                      prefixIcon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a username';
                                        }
                                        if (value.length < 3) {
                                          return 'Username must be at least 3 characters long';
                                        }
                                        return null;
                                      },
                                      enabled:
                                          !_isEditMode, // Disable username editing in edit mode
                                    ),
                                    SizedBox(height: isSmallScreen ? 12 : 20),
                                    _buildEmailField(),
                                    SizedBox(height: isSmallScreen ? 12 : 20),
                                    _buildPhoneNumberField(),
                                    SizedBox(height: isSmallScreen ? 12 : 20),
                                    _buildPasswordField(),
                                    SizedBox(height: isSmallScreen ? 12 : 20),
                                    _buildConfirmPasswordField(),
                                    SizedBox(height: isSmallScreen ? 20 : 32),
                                    isSmallScreen
                                        ? Column(
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: _submitForm,
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              screenHeight *
                                                              0.02,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12.0,
                                                          ),
                                                    ),
                                                    backgroundColor: _isEditMode
                                                        ? editModeColor
                                                        : primaryColor,
                                                    elevation: 2,
                                                  ),
                                                  child: Text(
                                                    _isEditMode
                                                        ? 'UPDATE ACCOUNT'
                                                        : 'CREATE ACCOUNT',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton(
                                                  onPressed: _clearForm,
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              screenHeight *
                                                              0.02,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12.0,
                                                          ),
                                                    ),
                                                    side: BorderSide(
                                                      color: _isEditMode
                                                          ? editModeColor
                                                          : primaryColor,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _isEditMode
                                                        ? 'CANCEL EDIT'
                                                        : 'CLEAR',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isEditMode
                                                          ? editModeColor
                                                          : primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: _clearForm,
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              screenHeight *
                                                              0.02,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12.0,
                                                          ),
                                                    ),
                                                    side: BorderSide(
                                                      color: _isEditMode
                                                          ? editModeColor
                                                          : primaryColor,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _isEditMode
                                                        ? 'CANCEL EDIT'
                                                        : 'CLEAR',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isEditMode
                                                          ? editModeColor
                                                          : primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: _submitForm,
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              screenHeight *
                                                              0.02,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12.0,
                                                          ),
                                                    ),
                                                    backgroundColor: _isEditMode
                                                        ? editModeColor
                                                        : primaryColor,
                                                    elevation: 2,
                                                  ),
                                                  child: Text(
                                                    _isEditMode
                                                        ? 'UPDATE ACCOUNT'
                                                        : 'CREATE ACCOUNT',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(
                                isSmallScreen ? 12.0 : 16.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Password Requirements',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: _isEditMode
                                          ? editModeColor
                                          : primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 8 : 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '• At least 8 characters\n• One uppercase letter\n• One number',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_isEditMode) ...[
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '• In edit mode, only password can be updated\n• Leave password fields empty to keep current password',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.email_outlined,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '• Email will be checked for uniqueness automatically',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.015,
                    ),
                    color: _isEditMode ? editModeColor : primaryColor,
                    child: Center(
                      child: Text(
                        '© 2025 Rooks IT Services',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
