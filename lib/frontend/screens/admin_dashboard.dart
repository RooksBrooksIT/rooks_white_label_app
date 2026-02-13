import 'package:flutter/material.dart';

import 'package:subscription_rooks_app/frontend/screens/admin_Engineer_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_tickets.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_barcode_scanner.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_brandandmodel_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_amc_customer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_nor_customer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_customer_report_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_device_config_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_barcode_details.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_engineer_updates.dart';
import 'package:subscription_rooks_app/frontend/screens/app_main_page.dart';
import 'package:subscription_rooks_app/frontend/screens/unified_login_screen.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/barcode_identifier.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';

import 'package:subscription_rooks_app/backend/screens/admin_dashboard.dart';

class admindashboard extends StatefulWidget {
  const admindashboard({super.key});

  @override
  _admindashboardState createState() => _admindashboardState();
}

class _admindashboardState extends State<admindashboard> {
  int engineerUpdateCount = 0;
  String adminName = 'Rooks Admin';
  String adminEmail = 'rooksadmin@email.com';

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadAdminData();
  }

  void _initStreams() {
    AdminDashboardBackend.getEngineerUpdateCountStream().listen((count) {
      if (mounted) {
        setState(() {
          engineerUpdateCount = count;
        });
      }
    });
  }

  void _loadAdminData() async {
    // In a real app, you might load this from shared preferences or Firestore
    // For now, we'll use the default values
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool? shouldLeave = await _showBackConfirmDialog(context);
        return shouldLeave ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          title: Text(
            '${ThemeService.instance.appName} Admin',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              bool? shouldLeave = await _showBackConfirmDialog(context);
              if (shouldLeave == true) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => UnifiedLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
              onPressed: () {
                _showLogoutConfirmationDialog(context);
              },
            ),
          ],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        // endDrawer: _buildDrawer(context),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group: Ticket Management
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  'Ticket Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Service Tickets',
                    icon: Icons.dashboard,
                    color: const Color(0xFF0B3470),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminPage_CusDetails(statusFilter: ""),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Call Log ',
                    icon: Icons.dashboard,
                    color: const Color.fromARGB(255, 24, 146, 89),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminDeliveryTickets(statusFilter: ''),
                        ),
                      );
                    },
                  ),

                  _buildDashboardCard(
                    title: 'Engineer Updates',
                    icon: Icons.engineering,
                    color: const Color(0xFFF57C00),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EngineerUpdates(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Create Tickets',
                    icon: Icons.file_copy,
                    color: const Color.fromARGB(255, 75, 120, 150),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateTickets(
                            statusFilter: '',
                            customerId: '',
                            customerName: '',
                            mobileNumber: '',
                            categoryName: '',
                            loggedInName: '',
                            name: '',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Group: Engineer Management
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  'Engineer Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3470),
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Create Engineer',
                    icon: Icons.person_add_alt_1,
                    color: const Color(0xFF1976D2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EngineerManagementPage(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Engineer Reports',
                    icon: Icons.note,
                    color: const Color.fromARGB(184, 3, 77, 236),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEngineerReports(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Engineer Attendance',
                    icon: Icons.how_to_reg,
                    color: const Color(0xFF00796B),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminAttendancePage(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Attendance Reports',
                    icon: Icons.analytics,
                    color: const Color(0xFF3949AB),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminAttendanceReportsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Group: Device Management
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  'Device Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3470),
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Brand & Model',
                    icon: Icons.branding_watermark,
                    color: const Color(0xFF7B1FA2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrandModelPage(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Device Configuration',
                    icon: Icons.devices,
                    color: const Color(0xFFD32F2F),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminDeviceConfigurationPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Group: Customer Management
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  'Customer Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3470),
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Create AMC',
                    icon: Icons.assignment,
                    color: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AMCCreatePage(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    title: 'Create Report',
                    icon: Icons.assignment,
                    color: const Color.fromARGB(255, 125, 46, 118),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerReportGenerator(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Group: Customer Management
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  'BarCode Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B3470),
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Barcode Scanner',
                    icon: Icons.assignment,
                    color: const Color.fromARGB(255, 126, 62, 2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminBarcodeScanner(),
                        ),
                      );
                    },
                  ),

                  _buildDashboardCard(
                    title: 'Barcode Identity',
                    icon: Icons.engineering,
                    color: const Color.fromARGB(255, 3, 49, 43),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BarcodeIdentifierScreen(
                            scannedBarcode:
                                '', // Replace with actual scanned barcode if available
                          ),
                        ),
                      );
                    },
                  ),

                  _buildDashboardCard(
                    title: 'Barcode Details',
                    icon: Icons.engineering,
                    color: const Color.fromARGB(255, 72, 55, 133),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminViewBarcodeDetails(
                            // Replace with actual scanned barcode if available
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text(
              adminName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(adminEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text('Logout'),
                  onTap: () {
                    _showLogoutConfirmationDialog(context);
                  },
                ),
                Divider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24.0, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AdminDashboardBackend.logout();

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const UnifiedLoginScreen(),
                ),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Yes, Logout'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showBackConfirmDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text(
          'Are you sure you want to go back to the main page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
