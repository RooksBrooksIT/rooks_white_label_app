import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/auth_selection_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_customerlogin_page.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {'id': 'Owner', 'label': 'Owner', 'icon': Icons.business_center_rounded},
    {'id': 'Worker', 'label': 'Worker', 'icon': Icons.engineering_rounded},
    {'id': 'Customer', 'label': 'Customer', 'icon': Icons.person_rounded},
  ];

  void _onContinue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role to continue.')),
      );
      return;
    }

    Widget targetScreen;
    switch (_selectedRole) {
      case 'Owner':
        targetScreen = const AuthSelectionScreen();
        break;
      case 'Worker':
        targetScreen = const Engineerlogin();
        break;
      case 'Customer':
        targetScreen = const AMCLoginPage();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.backgroundColor;
    final isDarkBackground = backgroundColor.computeLuminance() < 0.5;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDarkBackground ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Please select your role",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkBackground
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Welcome to ${theme.appName}. Please choose how you would like to use the platform today.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkBackground
                              ? Colors.grey[400]
                              : Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Horizontal Role Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role['id'];
                          return _RoleItem(
                            label: role['label'],
                            icon: role['icon'],
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedRole = role['id'];
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 48),
                      // Continue Button
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress Dots
                    ],
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

class _RoleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;
    final isDarkBackground =
        ThemeService.instance.backgroundColor.computeLuminance() < 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.1)
                  : (isDarkBackground ? Colors.grey[850] : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isDarkBackground
                          ? Colors.grey[800]!
                          : Colors.grey[100]!),
                width: 2,
              ),
              boxShadow: isSelected
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(
              icon,
              size: 40,
              color: isSelected
                  ? primaryColor
                  : (isDarkBackground ? Colors.grey[600] : Colors.grey[300]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? primaryColor
                  : (isDarkBackground
                        ? Colors.grey[400]
                        : Colors
                              .grey[400]), // grey[400] is usually okay on grey[900]
            ),
          ),
        ],
      ),
    );
  }
}
