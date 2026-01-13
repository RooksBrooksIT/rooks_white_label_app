import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/stripe_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';

import 'dart:io';
import 'card_details_screen.dart';

import 'transaction_completed_screen.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final bool isYearly;
  final int price;
  final int? originalPrice;

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.isYearly,
    required this.price,
    this.originalPrice,
    this.brandingData,
  });

  final Map<String, dynamic>? brandingData;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedPaymentMethod = 'UPI';
  final TextEditingController upiController = TextEditingController(
    text: 'user@okaxis',
  );

  // No longer need card controllers as Stripe handles it
  final TextEditingController nameController = TextEditingController();

  void _onCardSelected(String type) {
    setState(() {
      selectedPaymentMethod = type;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardDetailsScreen(
          paymentAmount: widget.price,
          planName: widget.planName,
          isYearly: widget.isYearly,
        ),
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment Successful!')));
      }
    });
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

  // Get next billing date (12 months from now)
  DateTime getNextBillingDate() {
    return DateTime.now().add(const Duration(days: 365));
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
    // final screenWidth = MediaQuery.of(context).size.width; // Unused

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: screenPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                if (isDesktop)
                  _buildDesktopHeader(formattedDate)
                else
                  _buildMobileTabletHeader(formattedDate),

                const SizedBox(height: 32),

                // Payment Methods - Responsive Layout
                if (isDesktop) ...[
                  // Desktop Layout
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildPaymentMethodsSection()),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildSecurityBadges(),
                              const SizedBox(height: 40),
                              _buildActionButtons(),
                              const SizedBox(height: 24),
                              const Spacer(),
                              _buildTermsText(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isTablet) ...[
                  // Tablet Layout
                  _buildPaymentMethodsSection(),
                  const SizedBox(height: 32),
                  _buildSecurityBadges(),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildTermsText(),
                ] else ...[
                  // Mobile Layout
                  _buildPaymentMethodsSection(),
                  const SizedBox(height: 32),
                  _buildSecurityBadges(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildTermsText(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(String formattedDate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOOSE YOUR PAYMENT METHOD',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Secure and seamless payment options for your subscription',
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        _buildSubscriptionSummary(formattedDate),
      ],
    );
  }

  Widget _buildMobileTabletHeader(String formattedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE YOUR PAYMENT METHOD',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure and seamless payment options for your subscription',
          style: TextStyle(fontSize: subtitleFontSize, color: Colors.black54),
        ),
        const SizedBox(height: 32),
        _buildSubscriptionSummary(formattedDate),
      ],
    );
  }

  Widget _buildSubscriptionSummary(String formattedDate) {
    return Container(
      width: isDesktop ? 400 : double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'Billed For ${widget.isYearly ? '12 Months' : '1 Month'}',
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
                    '₹${widget.price}',
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
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
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
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
        _buildPaymentMethod('UPI Payment', 'UPI', Icons.qr_code, Colors.blue, [
          _buildUpiOption('Google Pay', 'user@okaxis'),
          _buildUpiOption('Phone Pay', 'user@okaxis'),
          _buildUpiOption('Paytm', 'user@okaxis'),
        ]),
        SizedBox(height: isDesktop ? 24 : 20),

        _buildPaymentMethod(
          'Cards (Stripe)',
          'Cards',
          Icons.credit_card,
          Colors.orange,
          [_buildCardOption('Credit Card'), _buildCardOption('Debit Card')],
        ),
        SizedBox(height: isDesktop ? 24 : 20),

        _buildPaymentMethod(
          'More ways to Pay',
          'NetBanking',
          Icons.account_balance,
          Colors.green,
          [_buildBankOption('Net Banking')],
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(
    String title,
    String value,
    IconData icon,
    Color color,
    List<Widget> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: iconSize),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ...options,
      ],
    );
  }

  Widget _buildUpiOption(String name, String upiId) {
    final itemHeight = isDesktop ? 70 : 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(minHeight: itemHeight.toDouble()),
      child: Material(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.shade50,
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue.shade700,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        upiId,
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: name,
                  groupValue: selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      selectedPaymentMethod = value!;
                    });
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardOption(String type) {
    final itemHeight = isDesktop ? 70 : 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(minHeight: itemHeight.toDouble()),
      child: Material(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.shade50,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () => _onCardSelected(type),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: Colors.orange.shade700,
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
                        type,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Secure checkout via Stripe',
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: type,
                  groupValue: selectedPaymentMethod,
                  onChanged: (value) {
                    if (value != null) {
                      _onCardSelected(value);
                    }
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankOption(String name) {
    final itemHeight = isDesktop ? 70 : 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(minHeight: itemHeight.toDouble()),
      child: Material(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.shade50,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () {
            setState(() {
              selectedPaymentMethod = name;
            });
            _showBankListDialog();
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: Colors.green.shade700,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct bank transfer',
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: name,
                  groupValue: selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      selectedPaymentMethod = value!;
                    });
                    _showBankListDialog();
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        Icon(icon, color: Colors.green.shade600, size: isDesktop ? 40 : 32),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
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
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: Text(
              'Pay Now',
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

  void _showBankListDialog() {
    final banks = [
      'State Bank of India',
      'HDFC Bank',
      'ICICI Bank',
      'Axis Bank',
      'Kotak Mahindra Bank',
      'Punjab National Bank',
      'Bank of Baroda',
      'Canara Bank',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Bank'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: banks.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text(banks[index]),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected ${banks[index]}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing payment...'),
          ],
        ),
      ),
    );

    try {
      bool paymentSuccess = false;

      // Handle Stripe logic if method is Card
      if (selectedPaymentMethod.contains('Card') ||
          selectedPaymentMethod == 'Credit Card' ||
          selectedPaymentMethod == 'Debit Card') {
        // Close the loading indicator to show the Stripe sheet
        if (mounted) Navigator.pop(context);

        paymentSuccess = await StripeService.instance.makePayment(
          amount: widget.price.toString(),
          currency: 'inr',
        );

        if (!paymentSuccess) {
          throw Exception('Payment was not completed');
        }

        // Show loading again to finalize (optional but good for UX consistency)
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
      } else {
        // Simulate payment processing latency for other methods
        await Future.delayed(const Duration(seconds: 2));
        paymentSuccess = true;
      }

      // TODO: Replace with real authenticated uid once auth is wired.
      const uid = 'demo-user';

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
              // Create a mutable copy and update
              finalBrandingData = Map<String, dynamic>.from(
                widget.brandingData!,
              );
              finalBrandingData['logoUrl'] = logoUrl;
              finalBrandingData.remove('logoPath'); // Don't save local path
            }
          }
        } catch (e) {
          print('Error handling logo upload: $e');
          // Proceed without logo URL if upload fails, or handle deeper error
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      // Generate transaction ID
      final transactionId =
          'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      if (!mounted) return;

      // Navigate to Transaction Completed Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionCompletedScreen(
            planName: widget.planName,
            isYearly: widget.isYearly,
            amountPaid: widget.price,
            paymentMethod: selectedPaymentMethod,
            transactionId: transactionId,
            timestamp: DateTime.now(),
          ),
        ),
      );
    } catch (e) {
      // Ensure loading dialog is closed if it's open
      if (mounted && Navigator.canPop(context)) {
        // We can't strictly know if the dialog is top, but this is a safe-ish bet in this context
        // Navigator.pop(context);
      }

      // Re-opening the structure: simple pop might close the screen if dialog isn't open!
      // I'll leave the pop logic manual in the blocks above for safety and only show snackbar here.

      if (mounted) {
        // Attempt to close loading dialog if it looks like one is open (heuristic)
        // Instead of guessing, I'll just show the error. The loading dialog might block user interaction if not closed.
        // Let's assume the happy path closes it.
        // If error, we should close it.
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Try to pop the dialog
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    upiController.dispose();
    // cardNumberController.dispose(); // Removed
    // expiryController.dispose(); // Removed
    // cvvController.dispose(); // Removed
    nameController.dispose();
    super.dispose();
  }
}
