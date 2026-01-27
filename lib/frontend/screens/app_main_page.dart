import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_login_pages.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
// Import your customer page here

class AppMainPage extends StatelessWidget {
  const AppMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final isLargeScreen = width > 768;
    final isMediumScreen = width > 600;

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Subtle background pattern
            _buildBackgroundPattern(context),

            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 60 : 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Section
                    _buildHeaderSection(context, isLargeScreen),

                    SizedBox(height: isLargeScreen ? 60 : 40),

                    // Login Cards
                    _buildLoginCardsSection(context, isLargeScreen, width),

                    SizedBox(height: isLargeScreen ? 50 : 30),

                    // About Us Section
                    _buildAboutSection(context, isLargeScreen),

                    SizedBox(height: isLargeScreen ? 30 : 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPattern(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.03),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -40,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.03),
            ),
          ),
        ),
        Positioned(
          top: 150,
          left: -20,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.02),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, bool isLargeScreen) {
    final logoUrl = ThemeService.instance.logoUrl;
    return Column(
      children: [
        // Logo
        Container(
          padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: logoUrl != null
              ? Image.network(
                  logoUrl,
                  width: isLargeScreen ? 100 : 70,
                  height: isLargeScreen ? 100 : 70,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.business,
                    size: isLargeScreen ? 100 : 70,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : Image.asset(
                  'assets/images/logo.png',
                  width: isLargeScreen ? 100 : 70,
                  height: isLargeScreen ? 100 : 70,
                  fit: BoxFit.contain,
                  color: Theme.of(context).primaryColor,
                ),
        ),
        SizedBox(height: isLargeScreen ? 30 : 20),

        // Title
        Text(
          ThemeService.instance.appName,
          style: TextStyle(
            fontSize: isLargeScreen ? 42 : 32,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),

        // Subtitle
        Text(
          "Professional Service Management Solution",
          style: TextStyle(
            fontSize: isLargeScreen ? 18 : 14,
            color: Colors.black54,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCardsSection(
    BuildContext context,
    bool isLargeScreen,
    double width,
  ) {
    if (isLargeScreen) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProfessionalCard(
            context: context,
            title: "Customer",
            subtitle: "Access your services\nand requests",
            icon: Icons.person_outline,
            gradient: [Color(0xFF4CAF50), Color(0xFF45a049)],
            width: width * 0.26,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => CustomerTypePage()));
            },
          ),
          SizedBox(width: 24),
          _buildProfessionalCard(
            context: context,
            title: "Admin",
            subtitle: "Manage platform\nand users",
            icon: Icons.admin_panel_settings_outlined,
            gradient: [Color(0xFF2196F3), Color(0xFF1976D2)],
            width: width * 0.26,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AdminLogin()));
            },
          ),
          SizedBox(width: 24),
          _buildProfessionalCard(
            context: context,
            title: "Engineer",
            subtitle: "Handle service\nrequests",
            icon: Icons.engineering_outlined,
            gradient: [Color(0xFFFF9800), Color(0xFFF57C00)],
            width: width * 0.26,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => Engineerlogin()));
            },
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildProfessionalCard(
            context: context,
            title: "Customer",
            subtitle: "Access your services and requests",
            icon: Icons.person_outline,
            gradient: [Color(0xFF4CAF50), Color(0xFF45a049)],
            width: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => CustomerTypePage()));
            },
          ),
          SizedBox(height: 16),
          _buildProfessionalCard(
            context: context,
            title: "Admin",
            subtitle: "Manage platform and users",
            icon: Icons.admin_panel_settings_outlined,
            gradient: [Color(0xFF2196F3), Color(0xFF1976D2)],
            width: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AdminLogin()));
            },
          ),
          SizedBox(height: 16),
          _buildProfessionalCard(
            context: context,
            title: "Engineer",
            subtitle: "Handle service requests",
            icon: Icons.engineering_outlined,
            gradient: [Color(0xFFFF9800), Color(0xFFF57C00)],
            width: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => Engineerlogin()));
            },
          ),
        ],
      );
    }
  }

  Widget _buildProfessionalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required double width,
    VoidCallback? onTap, // Added optional onTap callback
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: width,
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap:
                onTap ??
                () {
                  _showLoginToast(context, title);
                },
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isLargeScreen) {
    return Column(
      children: [
        Text(
          "Version 1.2.0",
          style: TextStyle(
            color: Colors.grey,
            fontSize: isLargeScreen ? 16 : 14,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _showProfessionalAboutDialog(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 40 : 30,
              vertical: isLargeScreen ? 16 : 12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text(
                "About ${ThemeService.instance.appName}",
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLoginToast(BuildContext context, String userType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$userType Portal - Redirecting...'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showProfessionalAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                      SizedBox(height: 16),
                      Text(
                        ThemeService.instance.appName,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Enterprise Service Management Platform",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Text(
                        "${ThemeService.instance.appName} is a comprehensive enterprise solution designed to streamline service management processes. Our platform connects customers, administrators, and service engineers in a seamless ecosystem.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 25),

                      // Features Grid
                      Wrap(
                        spacing: 20,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFeatureChip(
                            Icons.security,
                            "Secure & Reliable",
                          ),
                          _buildFeatureChip(
                            Icons.rocket_launch,
                            "Fast Performance",
                          ),
                          _buildFeatureChip(
                            Icons.phone_iphone,
                            "Mobile Friendly",
                          ),
                          _buildFeatureChip(Icons.support, "24/7 Support"),
                        ],
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                        ),
                        child: Text("CLOSE"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Color(0xFF1E3C72)),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF1E3C72),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
