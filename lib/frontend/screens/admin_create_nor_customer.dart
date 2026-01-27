import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class EngineerManagementPage extends StatefulWidget {
  static Route route() =>
      MaterialPageRoute(builder: (_) => EngineerManagementPage());
  const EngineerManagementPage({super.key});

  @override
  _EngineerManagementPageState createState() => _EngineerManagementPageState();
}

class _EngineerManagementPageState extends State<EngineerManagementPage> {
  Future<bool> _onWillPop() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => admindashboard()),
      (Route<dynamic> route) => false,
    );
    return false;
  }

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _viewMode = false;
  bool _passwordVisible = false;
  List<Map<String, dynamic>> _engineers = [];

  String _confirmPasswordMessage = '';
  Color _confirmPasswordMessageColor = Colors.transparent;

  // Updated professional color scheme
  // Updated professional color scheme
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get secondaryColor => Theme.of(context).primaryColorLight;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get successColor => Colors.green;
  Color get textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get textLightColor => Theme.of(context).hintColor;

  @override
  void initState() {
    super.initState();
    _fetchEngineers();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Engineer Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _viewMode ? Icons.add_circle_outline : Icons.list_alt,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () {
                setState(() {
                  _viewMode = !_viewMode;
                  if (!_viewMode) _clearForm();
                });
              },
              tooltip: _viewMode ? 'Add New Engineer' : 'View Engineers',
            ),
          ],
        ),
        body: _viewMode ? _buildEngineersList() : _buildEngineerForm(),
      ),
    );
  }

  Widget _buildEngineerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.person_add, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Engineer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Form Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username Field
                    _buildFormField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person_outline,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a username'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    _buildFormField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPasswordField: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onChanged: (value) => _validateConfirmPassword(),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password Field
                    _buildFormField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock,
                      isPasswordField: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onChanged: (value) => _validateConfirmPassword(),
                    ),
                    const SizedBox(height: 8),

                    // Password validation message
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Text(
                        _confirmPasswordMessage,
                        style: TextStyle(
                          color: _confirmPasswordMessageColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email Field
                    _buildFormField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Phone Field
                    _buildFormField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a phone number'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Specialization Field
                    _buildFormField(
                      controller: _specializationController,
                      label: 'Specialization',
                      icon: Icons.engineering,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a specialization'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Existing Engineers Table
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Existing Engineers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEngineersTable(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _clearForm();
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: accentColor),
                  ),
                  child: Text(
                    'Clear Form',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final isValid = _formKey.currentState!.validate();
                          final passwordsMatch =
                              _passwordController.text ==
                              _confirmPasswordController.text;

                          if (!isValid) {
                            return;
                          }

                          if (!passwordsMatch) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Passwords do not match'),
                                backgroundColor: errorColor,
                              ),
                            );
                            return;
                          }

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Confirm Submission'),
                              content: Text(
                                'Are you sure you want to create this engineer account?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: textLightColor),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    'Confirm',
                                    style: TextStyle(color: accentColor),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirmed ?? false) {
                            _addEngineer();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Create Engineer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEngineersTable() {
    if (_engineers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No engineers found. Add your first engineer above.',
            style: TextStyle(color: textLightColor),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              Theme.of(context).scaffoldBackgroundColor,
        ),
        columns: [
          DataColumn(
            label: Text(
              'Name',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Specialization',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Phone',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
        rows: _engineers.map((engineer) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  engineer['Username'] ?? '-',
                  style: TextStyle(color: textColor),
                ),
              ),
              DataCell(
                Text(
                  engineer['Email'] ?? '-',
                  style: TextStyle(color: textColor),
                ),
              ),
              DataCell(
                Text(
                  engineer['Specialization'] ?? '-',
                  style: TextStyle(color: textColor),
                ),
              ),
              DataCell(
                Text(
                  engineer['Phone'] ?? '-',
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _validateConfirmPassword() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmPasswordMessage = '';
        _confirmPasswordMessageColor = Colors.transparent;
      } else if (password == confirm) {
        _confirmPasswordMessage = 'Passwords match';
        _confirmPasswordMessageColor = successColor;
      } else {
        _confirmPasswordMessage = 'Passwords do not match';
        _confirmPasswordMessageColor = errorColor;
      }
    });
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isPasswordField = false,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPasswordField ? !_passwordVisible : obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textLightColor),
        floatingLabelStyle: TextStyle(color: accentColor),
        prefixIcon: Icon(icon, color: textLightColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textLightColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textLightColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        filled: true,
        fillColor: backgroundColor,
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: textLightColor,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              )
            : null,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildEngineersList() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(Icons.people, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Engineer Directory',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Engineers List
          Expanded(
            child: _engineers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.engineering,
                          size: 64,
                          color: textLightColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No engineers found',
                          style: TextStyle(fontSize: 16, color: textLightColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a new engineer to get started',
                          style: TextStyle(fontSize: 14, color: textLightColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _engineers.length,
                    itemBuilder: (context, index) {
                      final engineer = _engineers[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.1),
                            child: Icon(Icons.engineering, color: accentColor),
                          ),
                          title: Text(
                            engineer['Username'] ?? 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                engineer['Specialization'] ??
                                    'No Specialization',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textLightColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                engineer['Email'] ?? 'No Email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textLightColor,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: errorColor),
                            onPressed: () => _deleteEngineer(engineer['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchEngineers() async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _engineers = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'Username': data['Username'],
            'Email': data['Email'],
            'Phone': data['Phone'],
            'Specialization': data['Specialization'],
          };
        }).toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch engineers: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addEngineer() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: errorColor,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final existingUserQuery = await FirestoreService.instance
            .collection('EngineerLogin')
            .where('Username', isEqualTo: _usernameController.text)
            .get();

        if (existingUserQuery.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Username already exists'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final now = DateTime.now();
        final formattedDate =
            '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';

        final docId = '${_usernameController.text}_$formattedDate';

        await FirestoreService.instance
            .collection('EngineerLogin')
            .doc(docId)
            .set({
              'Username': _usernameController.text,
              'Password': _passwordController.text,
              'Email': _emailController.text,
              'Phone': _phoneController.text,
              'Specialization': _specializationController.text,
              'createdAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Engineer created successfully!'),
            backgroundColor: successColor,
          ),
        );

        _clearForm();
        _fetchEngineers();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create engineer: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEngineer(String? id) async {
    if (id == null) return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Delete', style: TextStyle(color: textColor)),
        content: Text(
          'Are you sure you want to delete this engineer?',
          style: TextStyle(color: textLightColor),
        ),
        backgroundColor: cardColor,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: textLightColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    );

    if (confirmDelete) {
      try {
        await FirestoreService.instance
            .collection('EngineerLogin')
            .doc(id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Engineer deleted successfully'),
            backgroundColor: successColor,
          ),
        );

        _fetchEngineers();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete engineer: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _clearForm() {
    FocusScope.of(context).unfocus();
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _emailController.clear();
    _phoneController.clear();
    _specializationController.clear();
    setState(() {
      _confirmPasswordMessage = '';
      _confirmPasswordMessageColor = Colors.transparent;
      _passwordVisible = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    super.dispose();
  }
}
