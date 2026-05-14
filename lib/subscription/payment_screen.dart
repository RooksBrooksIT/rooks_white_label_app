import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'icici_payment_webview_screen.dart';

import 'dart:io';
import 'dart:async';

import 'transaction_completed_screen.dart';
import 'payment_failed_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final bool isYearly;
  final bool isSixMonths;
  final int price;
  final int? originalPrice;
  final Map<String, dynamic>? brandingData;
  final bool isFirstTimeRegistration;

  // New fields for plan limits and features
  final Map<String, dynamic>? limits;
  final bool? geoLocation;
  final bool? attendance;
  final bool? barcode;
  final bool? reportExport;
  final String initialPaymentMethod;

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.isYearly,
    this.isSixMonths = false,
    required this.price,
    this.originalPrice,
    this.brandingData,
    this.isFirstTimeRegistration = true,
    this.limits,
    this.geoLocation,
    this.attendance,
    this.barcode,
    this.reportExport,
    this.initialPaymentMethod = 'UPI',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color brandBlue = Color(0xFF1A237E);
  late String selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    selectedPaymentMethod = widget.initialPaymentMethod;
  }

  // Responsive values based on screen width
  double get titleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 32; // Web
    if (width > 768) return 28; // Tablet
    return 22; // Phone
  }

  double get subtitleFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 20;
    if (width > 768) return 18;
    return 16;
  }

  double get priceFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 40;
    if (width > 768) return 34;
    return 28;
  }

  double get buttonFontSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 18;
  }

  double get buttonHeight {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 64;
    return 56;
  }

  EdgeInsets get screenPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return EdgeInsets.symmetric(horizontal: width * 0.1, vertical: 32);
    }
    if (width > 768) {
      return EdgeInsets.symmetric(horizontal: width * 0.08, vertical: 24);
    }
    return const EdgeInsets.all(20);
  }

  double get containerPadding {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 24;
    return 20;
  }

  double get borderRadius {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 20;
    return 16;
  }

  double get iconSize {
    final width = MediaQuery.of(context).size.width;
    if (width > 768) return 28;
    return 24;
  }

  bool get isDesktop => MediaQuery.of(context).size.width > 1200;
  bool get isTablet =>
      MediaQuery.of(context).size.width > 768 &&
      MediaQuery.of(context).size.width <= 1200;
  bool get isMobile => MediaQuery.of(context).size.width <= 768;

  // Get next billing date
  DateTime getNextBillingDate() {
    if (widget.isYearly) {
      return DateTime.now().add(const Duration(days: 365));
    } else if (widget.isSixMonths) {
      // Best way to add 6 months:
      final now = DateTime.now();
      return DateTime(now.year, now.month + 6, now.day);
    } else {
      return DateTime.now().add(const Duration(days: 30));
    }
  }

  // Format date as "Mon YYYY"
  String formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nextBillingDate = getNextBillingDate();
    final formattedDate = formatDate(nextBillingDate);

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: brandBlue,
        colorScheme: const ColorScheme.light(
          primary: brandBlue,
          secondary: brandBlue,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Payment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Section (Moved to top for better flow)
                _buildSubscriptionSummary(formattedDate),

                const SizedBox(height: 32),

                // Title Section
                Text(
                  'SELECT PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: titleFontSize * 0.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure and seamless payment options',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                // Responsive Layout for Payment Methods
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildPaymentMethodsSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 1, child: _buildRightSideSidebar()),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPaymentMethodsSection(),
                      const SizedBox(height: 32),
                      _buildSecurityBadges(),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildTermsText(),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideSidebar() {
    return Column(
      children: [
        _buildSecurityBadges(),
        const SizedBox(height: 40),
        _buildActionButtons(),
        const SizedBox(height: 24),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildSubscriptionSummary(String formattedDate) {
    return Container(
      width: isDesktop ? 400 : double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBSCRIPTION SUMMARY',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.planName} Plan',
                      style: TextStyle(
                        fontSize: isDesktop ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          widget.price == 0
                              ? '7 Days Free Trial'
                              : 'Billed For ${widget.isYearly ? '12 Months' : (widget.isSixMonths ? '6 Months' : '1 Month')}',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: isDesktop ? 16 : 14,
                          ),
                        ),
                        Text(
                          'Next Billing $formattedDate',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.originalPrice != null)
                    Text(
                      '₹${widget.originalPrice}',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    widget.price == 0 ? 'Free' : '₹${widget.price}',
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.swap_horiz, size: isDesktop ? 20 : 18),
              label: Text(
                'Change plan',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSimplePaymentOption(
          name: 'UPI',
          subtitle: 'Google Pay, PhonePe, Paytm & more',
          icon: Icons.qr_code_rounded,
          color: brandBlue,
          showUpiApps: true,
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        _buildSimplePaymentOption(
          name: 'Card',
          subtitle: 'Credit / Debit card payment',
          icon: Icons.credit_card_rounded,
          color: brandBlue.withOpacity(0.8),
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        _buildSimplePaymentOption(
          name: 'Net Banking',
          subtitle: 'Direct bank transfer',
          icon: Icons.account_balance_rounded,
          color: brandBlue.withOpacity(0.9),
        ),
      ],
    );
  }

  Widget _buildSimplePaymentOption({
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool showUpiApps = false,
  }) {
    final isSelected = selectedPaymentMethod == name;
    final itemHeight = isDesktop ? 70.0 : 64.0;

    return Column(
      children: [
        Container(
          constraints: BoxConstraints(minHeight: itemHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: () {
                setState(() {
                  selectedPaymentMethod = name;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 16 : 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: isDesktop ? 48 : 40,
                      height: isDesktop ? 48 : 40,
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: isDesktop ? 24 : 20,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.black87
                              : Colors.grey.shade400,
                          width: isSelected ? 6 : 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showUpiApps && isSelected) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUpiAppIcon(
                  'Google Pay',
                  Icons.account_balance_wallet_outlined,
                  onTap: () => _processPayment(),
                ),
                _buildUpiAppIcon(
                  'PhonePe',
                  Icons.phone_android_outlined,
                  onTap: () => _processPayment(),
                ),
                _buildUpiAppIcon(
                  'Paytm',
                  Icons.payment_outlined,
                  onTap: () => _processPayment(),
                ),
                _buildUpiAppIcon(
                  'Other',
                  Icons.more_horiz,
                  onTap: () => _processPayment(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'Clicking "Pay via UPI" will open your installed UPI apps',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpiAppIcon(String name, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Check if this is a UPI payment that should launch the system UPI chooser.
  bool _isUpiMethod(String method) {
    return method == 'UPI';
  }

  Widget _buildSecurityBadges() {
    return Row(
      mainAxisAlignment: isMobile
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        _buildSecurityBadge('256-BIT SSL ENCRYPTED', Icons.lock),
        SizedBox(width: isDesktop ? 32 : 20),
        _buildSecurityBadge('100% SAFE PAYMENTS', Icons.verified_user),
      ],
    );
  }

  Widget _buildSecurityBadge(String text, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: brandBlue, size: isDesktop ? 40 : 32),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: brandBlue,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttonWidth = isDesktop ? 400.0 : double.infinity;

    return Column(
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              _processPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              selectedPaymentMethod == 'UPI' ? 'Pay via UPI' : 'Pay Now',
              style: TextStyle(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: buttonFontSize - 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20),
        child: Text(
          'By Processing this Payment, you agree to our Terms of Services\nand Return Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    final uid = AuthStateService.instance.currentUser?.uid ?? 'demo-user';
    final txnRefId = DateTime.now().millisecondsSinceEpoch.toString();

    await _processIciciPayment(uid: uid);
  }

  /// Strips HTML and Exception prefix from error messages for user display.
  String _cleanErrorMessage(String raw) {
    String msg = raw.replaceFirst('Exception: ', '');
    if (msg.trim().startsWith('<')) {
      return 'Payment gateway error. Please try again or contact support.';
    }
    return msg;
  }

  /// Process payment via ICICI initiateSale (Standard Web Flow).
  Future<void> _processIciciPayment({required String uid}) async {
    // Show initiating dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initiating secure payment...'),
          ],
        ),
      ),
    );

    try {
      final tenantId = ThemeService.instance.databaseName;
      final appId = ThemeService.instance.appName;
      final email =
          AuthStateService.instance.currentUser?.email ??
          'customer@example.com';

      // Fetch customer data for pre-filling
      final customerData = await IciciService.instance.fetchCustomerData(
        uid,
        tenantId,
      );

      // 1. Initiate Sale via backend
      final paymentMode = selectedPaymentMethod == 'Net Banking'
          ? 'NETBANKING'
          : selectedPaymentMethod.toUpperCase();
          
      debugPrint("Selected Payment Mode: $paymentMode");
      debugPrint("Request Payload: { amount: ${widget.price}, email: $email, tenantId: $tenantId, appId: $appId, paymentMode: $paymentMode }");

      final response = await IciciService.instance.initiatePayment(
        amount: widget.price.toString(),
        email: email,
        tenantId: tenantId,
        appId: appId,
        paymentMode: paymentMode,
        planName: widget.planName,
        customerName: customerData['name'],
        customerMobile: customerData['phone'],
        isYearly: widget.isYearly,
        isSixMonths: widget.isSixMonths,
        limits: widget.limits,
        geoLocation: widget.geoLocation,
        attendance: widget.attendance,
        barcode: widget.barcode,
        reportExport: widget.reportExport,
      );

      debugPrint("Backend Response: { success: ${response.success}, txnId: ${response.txnId}, error: ${response.error} }");

      if (!mounted) return;
      Navigator.pop(context); // Close initiating dialog

      if (!response.success || response.redirectUrl == null) {
        throw Exception(response.error ?? 'Failed to initiate payment');
      }

      // 2. Handle based on payment mode
      if (selectedPaymentMethod == 'UPI') {
        // Direct UPI Launch Flow
        await _handleUpiLaunchFlow(response, uid);
      } else {
        // Standard Web Flow (Card/NetBanking)
        await _handleWebFlow(response, uid);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final errorMessage = _cleanErrorMessage(e.toString());
      debugPrint("Payment Initiation Error: $errorMessage");

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Instead of navigating away immediately on initiation error, 
      // show a helpful snackbar so the user can try again or change method.
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => PaymentFailedScreen(
                    errorMessage: errorMessage,
                    paymentMethod: selectedPaymentMethod,
                    amount: widget.price,
                    transactionId: 'INIT_ERROR',
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  /// Handle Direct UPI App Launch
  Future<void> _handleUpiLaunchFlow(IciciPaymentResponse response, String uid) async {
    final upiUrl = response.redirectUrl!;
    final txnId = response.txnId ?? '';

    debugPrint("Launching UPI URL: $upiUrl");

    // 1. Launch UPI App
    try {
      final uri = Uri.parse(upiUrl);
      
      if (Platform.isAndroid || Platform.isIOS) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback for web/desktop if ever reached
        await launchUrl(uri);
      }

      // 2. Show the robust status polling dialog
      if (mounted) {
        final bool? success = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _UpiStatusDialog(
            txnId: txnId,
            upiUrl: upiUrl,
          ),
        );

        if (success == true) {
          _navigateToSuccess(txnId);
        } else {
          // If the user cancelled or it failed/timed out
          // The dialog already handles its own closing
        }
      }
    } catch (e) {
      debugPrint("UPI Launch Error: $e");
      rethrow;
    }
  }

  void _navigateToSuccess(String txnId) {
    if (!mounted) return;
    
    // Ensure all dialogs are closed before navigating to the final screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => TransactionCompletedScreen(
          transactionId: txnId,
          planName: widget.planName,
          amountPaid: widget.price,
          isYearly: widget.isYearly,
          paymentMethod: selectedPaymentMethod,
          timestamp: DateTime.now(),
          isFirstTimeRegistration: widget.isFirstTimeRegistration,
          isSixMonths: widget.isSixMonths,
          originalPrice: widget.originalPrice,
          limits: widget.limits,
          geoLocation: widget.geoLocation,
          attendance: widget.attendance,
          barcode: widget.barcode,
          reportExport: widget.reportExport,
        ),
      ),
      (route) => route.isFirst, // Go back to dashboard/first route
    );
  }

  /// Handle Standard Web Flow (WebView)
  Future<void> _handleWebFlow(IciciPaymentResponse response, String uid) async {
    final result = await Navigator.push<IciciPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (context) => IciciPaymentWebViewScreen(
          paymentUrl: response.redirectUrl!,
          merchantTxnNo: response.txnId ?? '',
          returnUrl: IciciService.returnUrl,
        ),
      ),
    );

    if (result == null || !result.success) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailedScreen(
            errorMessage: result?.message ?? 'Payment cancelled or failed',
            paymentMethod: selectedPaymentMethod,
            amount: widget.price,
            transactionId: response.txnId,
          ),
        ),
      );
      return;
    }

    // Handle Success
    await _handlePaymentSuccess(
      uid: uid,
      merchantTxnNo: response.txnId ?? '',
    );
  }

  /// Handle successful payment: upload logo (if any) and navigate to success screen.
  Future<void> _handlePaymentSuccess({
    required String uid,
    required String merchantTxnNo,
  }) async {
    // Show finalizing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finalizing subscription...'),
            ],
          ),
        ),
      );
    }

    try {
      // Upload logo if exists
      Map<String, dynamic>? finalBrandingData = widget.brandingData;

      if (widget.brandingData != null &&
          widget.brandingData!['logoPath'] != null) {
        try {
          final File logoFile = File(widget.brandingData!['logoPath']);
          if (await logoFile.exists()) {
            final logoUrl = await StorageService.instance.uploadLogo(
              userId: uid,
              file: logoFile,
            );
            if (logoUrl != null) {
              finalBrandingData = Map<String, dynamic>.from(
                widget.brandingData!,
              );
              finalBrandingData['logoUrl'] = logoUrl;
              finalBrandingData.remove('logoPath');
            }
          }
        } catch (e) {
          debugPrint('Error handling logo upload: $e');
        }
      }

      // ── Subscription processed successfully. Cloud Function will handle receipt and write subscription limits to Firestore via processPaymentSuccess. ──

      // Update just the user's active flag so UI unlocks immediately if needed
      final tenantId = ThemeService.instance.databaseName;
      try {
        await FirestoreService.instance.setUserActiveStatus(
          uid: uid,
          tenantId: tenantId,
          active: true,
        );
      } catch (e) {
        debugPrint('Error setting active status: $e');
      }

      if (mounted) Navigator.pop(context); // Close finalizing dialog

      final transactionId = 'TXN$merchantTxnNo';

      if (!mounted) return;

      // Navigate to Transaction Completed Screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionCompletedScreen(
            planName: widget.planName,
            isYearly: widget.isYearly,
            amountPaid: widget.price,
            paymentMethod: selectedPaymentMethod,
            transactionId: transactionId,
            timestamp: DateTime.now(),
            isFirstTimeRegistration: widget.isFirstTimeRegistration,
            isSixMonths: widget.isSixMonths,
            originalPrice: widget.originalPrice,
            limits: widget.limits,
            geoLocation: widget.geoLocation,
            attendance: widget.attendance,
            barcode: widget.barcode,
            reportExport: widget.reportExport,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      rethrow;
    }
  }
}

/// A dedicated widget to handle UPI payment status polling
class _UpiStatusDialog extends StatefulWidget {
  final String txnId;
  final String upiUrl;
  const _UpiStatusDialog({required this.txnId, required this.upiUrl});

  @override
  State<_UpiStatusDialog> createState() => _UpiStatusDialogState();
}

class _UpiStatusDialogState extends State<_UpiStatusDialog> {
  String statusText = 'Waiting for payment confirmation...';
  bool isVerifying = false;
  Timer? _timer;
  int _secondsLeft = 120; // 2 minutes timeout

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkStatus();
      setState(() {
        _secondsLeft -= 3;
      });
      if (_secondsLeft <= 0) {
        timer.cancel();
        Navigator.pop(context, false); // Timeout
      }
    });
  }

  Future<void> _checkStatus() async {
    if (!mounted || isVerifying) return;
    setState(() => isVerifying = true);

    try {
      // First check Firestore (Real-time update from bank callback)
      final doc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.txnId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final status = doc.data()?['status'];
        if (status == 'SUCCESS') {
          _timer?.cancel(); // Stop timer immediately
          Navigator.pop(context, true);
          return;
        } else if (status == 'FAILED') {
          _timer?.cancel();
          Navigator.pop(context, false);
          return;
        }
      }

      // Then call verify API (Secondary poll)
      // We wrap this in a sub-try-catch to ignore 400/500 errors 
      // which are common if the bank API is busy or the txn is too new.
      try {
        final verifyResult = await IciciService.instance.verifyPaymentStatus(txnId: widget.txnId);
        
        if (!mounted) return;

        if (verifyResult['status'] == 'SUCCESS') {
          _timer?.cancel();
          Navigator.pop(context, true);
          return;
        } else if (verifyResult['status'] == 'FAILED') {
          _timer?.cancel();
          Navigator.pop(context, false);
          return;
        }
      } catch (apiErr) {
        // Silently ignore API errors during polling to keep logs clean
        debugPrint('Polling: Verification API skipped (likely transient)');
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.green),
          SizedBox(width: 12),
          Text('UPI Payment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 24),
          if (widget.upiUrl.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: widget.upiUrl,
                version: QrVersions.auto,
                size: 180.0,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            'Please scan the QR or complete the payment in your UPI app.\nDo not close this screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            'Time remaining: ${_secondsLeft}s',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context, false);
          },
          child: const Text('Cancel Payment', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
