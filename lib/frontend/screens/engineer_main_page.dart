// import 'package:flutter/material.dart';
// import 'package:subscription_rooks_app/frontend/screens/engineer_barcode_scanner_page.dart';
// import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart';

// class EngineerMainPage extends StatefulWidget {
//   final String userName;
//   final VoidCallback? onLogout;

//   const EngineerMainPage({
//     super.key,
//     required this.userName,
//     this.onLogout,
//     required String userEmail,
//   });

//   @override
//   State<EngineerMainPage> createState() => _EngineerMainPageState();
// }

// class _EngineerMainPageState extends State<EngineerMainPage> {
//   get engineerName => widget.userName;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // Page background color (as requested)
//       backgroundColor: const Color(0xFF1E3C72),
//       body: NestedScrollView(
//         headerSliverBuilder: (context, innerBoxIsScrolled) {
//           return [
//             SliverAppBar(
//               expandedHeight: 120,
//               collapsedHeight: 64,
//               floating: true,
//               pinned: true,
//               snap: true,
//               backgroundColor: PremiumTheme.surface,
//               elevation: 0,
//               shape: const RoundedRectangleBorder(
//                 borderRadius: BorderRadius.only(
//                   bottomLeft: Radius.circular(24),
//                   bottomRight: Radius.circular(24),
//                 ),
//               ),
//               flexibleSpace: FlexibleSpaceBar(
//                 title: AnimatedOpacity(
//                   duration: PremiumAnimations.quick,
//                   opacity: innerBoxIsScrolled ? 1.0 : 0.0,
//                   child: Text(
//                     'Engineer Dashboard',
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       color: Color(0xFF1E3C72),
//                     ),
//                   ),
//                 ),
//                 background: Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
//                     ),
//                     borderRadius: BorderRadius.only(
//                       bottomLeft: Radius.circular(24),
//                       bottomRight: Radius.circular(24),
//                     ),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 24, bottom: 24),
//                     child: Align(
//                       alignment: Alignment.bottomLeft,
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Welcome back,',
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.white,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             widget.userName,
//                             style: TextStyle(
//                               fontSize: 24,
//                               color: PremiumTheme.textInverse,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 Container(
//                   margin: const EdgeInsets.only(right: 16),
//                   child: IconButton(
//                     onPressed: _showPremiumLogoutConfirmation,
//                     icon: Icon(
//                       Icons.logout_rounded,
//                       color: innerBoxIsScrolled
//                           ? PremiumTheme.textPrimary
//                           : PremiumTheme.textInverse,
//                     ),
//                     tooltip: 'Logout',
//                   ),
//                 ),
//               ],
//             ),
//           ];
//         },
//         body: SafeArea(
//           top: false, // Let the sliver header control the top area
//           child: ListView(
//             padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//             physics: const BouncingScrollPhysics(),
//             children: [
//               _dashboardCard(
//                 title: 'Tickets Overview',
//                 subtitle: 'View and manage your assigned tickets',
//                 icon: Icons.receipt_long_rounded,
//                 onTap: () {
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) =>
//                           EngineerPage(userEmail: '', userName: engineerName),
//                     ),
//                   );
//                 },
//               ),
//               const SizedBox(height: 16),
//               _dashboardCard(
//                 title: 'Warranty Check',
//                 subtitle: 'Scan or search product warranty',
//                 icon: Icons.verified_rounded,
//                 onTap: () {
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => BarcodeScannerScreen(userName: '',),
//                     ),
//                   );
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Dashboard Card widget
//   Widget _dashboardCard({
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       borderRadius: BorderRadius.circular(16),
//       onTap: onTap,
//       child: Container(
//         height: 120,
//         decoration: BoxDecoration(
//           color: Colors.white, // Displays nicely over the blue page background
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: PremiumTheme.borderLight),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.06),
//               offset: const Offset(0, 6),
//               blurRadius: 16,
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Container(
//               width: 56,
//               height: 56,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1E3C72).withOpacity(0.08),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(
//                 Icons.dashboard_rounded,
//                 size: 0,
//               ), // placeholder to set constraints
//             ),
//             Container(
//               width: 56,
//               height: 56,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1E3C72).withOpacity(0.08),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Icon(icon, color: const Color(0xFF1E3C72), size: 28),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w800,
//                       color: PremiumTheme.textPrimary,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     subtitle,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: PremiumTheme.textSecondary,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Icon(
//               Icons.arrow_forward_ios_rounded,
//               size: 18,
//               color: Colors.black38,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Navigation handlers (replace with your routing)
//   void _openTicketsOverview() {
//     // Example using named route:
//     // Navigator.pushNamed(context, '/ticketsOverview');
//     // Or with a page:
//     // Navigator.push(context, MaterialPageRoute(builder: (_) => TicketsOverviewPage()));
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Open Tickets Overview')));
//   }

//   void _openWarrantyCheck() {
//     // Example using named route:
//     // Navigator.pushNamed(context, '/warrantyCheck');
//     // Or with a page:
//     // Navigator.push(context, MaterialPageRoute(builder: (_) => WarrantyCheckPage()));
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Open Warranty Check')));
//   }

//   // Logout confirmation dialog
//   Future<void> _showPremiumLogoutConfirmation() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: true,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Logout'),
//         content: const Text('Are you sure you want to logout?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(false),
//             child: Text(
//               'Cancel',
//               style: TextStyle(color: PremiumTheme.textSecondary),
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF1E3C72),
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             onPressed: () => Navigator.of(ctx).pop(true),
//             child: const Text('Logout'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       widget.onLogout?.call();
//     }
//   }
// }

// /// Placeholder for PremiumTheme to show expected members.
// /// Remove this block if your project already defines PremiumTheme.
// class PremiumTheme {
//   static Color get surface => ThemeService.instance.backgroundColor;
//   static Color get textPrimary => const Color(0xFF111111);
//   static Color get textSecondary => const Color(0xFF666666);
//   static Color get textInverse => Colors.white;
//   static Color get borderLight => const Color(0xFFE8E8ED);
// }

// /// Placeholder for PremiumAnimations to show expected members.
// /// Remove this block if your project already defines PremiumAnimations.
// class PremiumAnimations {
//   static const Duration quick = Duration(milliseconds: 180);
// }
