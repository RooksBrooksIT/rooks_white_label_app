import 'package:flutter/material.dart';

import 'package:subscription_rooks_app/frontend/screens/admin_Engineer_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_assign_tickets.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_barcode_scanner.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_brandandmodel_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_amc_customer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_create_engineer.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_customer_report_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_device_config_page.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_barcode_details.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_view_engineer_updates.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_tickets_overview.dart';
import 'package:subscription_rooks_app/frontend/screens/barcode_identifier.dart';
import 'package:subscription_rooks_app/frontend/screens/unified_login_screen.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:flutter/services.dart';

import 'package:subscription_rooks_app/backend/screens/admin_dashboard.dart';

class admindashboard extends StatefulWidget {
  const admindashboard({super.key});

  @override
  _admindashboardState createState() => _admindashboardState();
}

class _admindashboardState extends State<admindashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int engineerUpdateCount = 0;
  int totalCustomers = 0;
  int activeEngineers = 0;
  int pendingTickets = 0;
  String adminName = 'Loading...';
  String adminEmail = '';
  String referralCode = '';
  DateTime? _lastBackPressed;

  // Dynamic Color Palette from ThemeService
  late Color primaryColor;
  late Color secondaryColor;
  late Color backgroundColor;
  final Color accentColor = const Color(0xFF00D2FF);
  final Color textColor = const Color(0xFF2D3436);
  final Color textLightColor = const Color(0xFF636E72);
  final Color errorColor = const Color(0xFFD63031);
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadAdminData();
  }

  void _initStreams() {
    AdminDashboardBackend.getEngineerUpdateCountStream().listen((count) {
      if (mounted) setState(() => engineerUpdateCount = count);
    });
    AdminDashboardBackend.getTotalCustomersStream().listen((count) {
      if (mounted) setState(() => totalCustomers = count);
    });
    AdminDashboardBackend.getActiveEngineersStream().listen((count) {
      if (mounted) setState(() => activeEngineers = count);
    });
    AdminDashboardBackend.getPendingTicketsStream().listen((count) {
      if (mounted) setState(() => pendingTickets = count);
    });
  }

  void _loadAdminData() async {
    final profile = await AdminDashboardBackend.getAdminProfile();
    final code = await AdminDashboardBackend.getReferralCode();
    if (mounted) {
      setState(() {
        adminName = profile['name']!;
        adminEmail = profile['email']!;
        referralCode = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh colors from ThemeService
    primaryColor = ThemeService.instance.primaryColor;
    secondaryColor = ThemeService.instance.secondaryColor;
    backgroundColor = ThemeService.instance.backgroundColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        endDrawer: _buildDrawer(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildMetricsSection(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildManagementSection('Ticket Management', [
                      _buildMenuCard(
                        title: 'Service Tickets',
                        subtitle: 'Manage support requests',
                        icon: Icons.confirmation_number_rounded,
                        color: const Color(0xFF0984E3),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminPage_CusDetails(statusFilter: ""),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Call Logs',
                        subtitle: 'Track interactions',
                        icon: Icons.phone_callback_rounded,
                        color: const Color(0xFF00B894),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminDeliveryTickets(statusFilter: ""),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Engineer Updates',
                        subtitle: 'Real-time activities',
                        icon: Icons.engineering_rounded,
                        color: const Color(0xFFE17055),
                        badge: engineerUpdateCount > 0
                            ? engineerUpdateCount.toString()
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EngineerUpdates(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Staff Hub', [
                      _buildMenuCard(
                        title: 'Engineers',
                        subtitle: 'Team management',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF6C5CE7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EngineerManagementPage(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Attendance',
                        subtitle: 'Check-in history',
                        icon: Icons.how_to_reg_rounded,
                        color: const Color(0xFFF0932B),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminAttendancePage(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Attendance Reports',
                        subtitle: 'Analytics and logs',
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF3949AB),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminAttendanceReportsPage(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Customer Hub', [
                      _buildMenuCard(
                        title: 'Create AMC',
                        subtitle: 'New service contract',
                        icon: Icons.assignment_ind_rounded,
                        color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AMCCreatePage(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Service Reports',
                        subtitle: 'Generate customer reports',
                        icon: Icons.assessment_rounded,
                        color: const Color(0xFF7D2E76),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerReportGenerator(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Device & Assets', [
                      _buildMenuCard(
                        title: 'Brand & Model',
                        subtitle: 'Catalog management',
                        icon: Icons.branding_watermark_rounded,
                        color: const Color(0xFFD63031),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrandModelPage(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Configuration',
                        subtitle: 'Device parameters',
                        icon: Icons.settings_input_component_rounded,
                        color: const Color(0xFF2D3436),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminDeviceConfigurationPage(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildManagementSection('Inventory Control', [
                      _buildMenuCard(
                        title: 'Barcode Hub',
                        subtitle: 'Scanner and verification',
                        icon: Icons.qr_code_scanner_rounded,
                        color: const Color(0xFF1E3799),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminBarcodeScanner(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Identity',
                        subtitle: 'Asset verification',
                        icon: Icons.fact_check_rounded,
                        color: const Color(0xFF38ADA9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BarcodeIdentifierScreen(scannedBarcode: ""),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Barcode Details',
                        subtitle: 'Comprehensive asset info',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF483785),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminViewBarcodeDetails(),
                          ),
                        ),
                      ),
                      _buildMenuCard(
                        title: 'Engineer Location',
                        subtitle: 'Comprehensive asset info',
                        icon: Icons.location_pin,
                        color: const Color(0xFF483785),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminGeoLocationScreen(
                              engineerId: '',
                              engineerName: '',
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryColor,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, secondaryColor],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome backs,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            adminName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildMetricCard(
                'Total Customers',
                totalCustomers.toString(),
                Icons.people_rounded,
                accentColor,
              ),
              _buildMetricCard(
                'Active Engineers',
                activeEngineers.toString(),
                Icons.engineering_rounded,
                const Color(0xFF00D2FF),
              ),
              _buildMetricCard(
                'Pending Tickets',
                pendingTickets.toString(),
                Icons.pending_actions_rounded,
                const Color(0xFFFF7675),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Create Ticket',
                Icons.add_task_rounded,
                primaryColor,
                () => Navigator.push(
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
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Reports',
                Icons.analytics_rounded,
                secondaryColor,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminEngineerReports(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSection(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        ...cards,
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: textLightColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.qr_code_rounded,
                  title: 'Referral Code',
                  subtitle: referralCode.isEmpty
                      ? 'Not Available'
                      : referralCode,
                  subtitleStyle: TextStyle(
                    fontSize: referralCode.isEmpty ? 14 : 18,
                    fontWeight: referralCode.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w900,
                    color: referralCode.isEmpty ? textLightColor : primaryColor,
                    letterSpacing: referralCode.isEmpty ? 0 : 1.2,
                  ),
                  onTap: () {
                    if (referralCode.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referral code copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  trailing: referralCode.isNotEmpty
                      ? const Icon(Icons.copy_rounded, size: 20)
                      : null,
                ),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Manage your profile',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile management coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  color: errorColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: textLightColor.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            adminName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            adminEmail,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? color,
    TextStyle? subtitleStyle,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? primaryColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color ?? textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            subtitleStyle ??
            TextStyle(
              fontSize: 12,
              color: textLightColor,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: errorColor, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to log out?',
                style: TextStyle(color: textLightColor),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: textLightColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await AdminDashboardBackend.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const UnifiedLoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
