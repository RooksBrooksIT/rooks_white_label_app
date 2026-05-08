/**
 * Flutter UI: Payment Processing Screen
 * File: lib/subscription/payment_processing_screen.dart
 * 
 * Example implementation showing how to use PaymentService
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String productDescription;

  const PaymentProcessingScreen({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.productDescription,
  }) : super(key: key);

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  late PaymentService _paymentService;
  PaymentResponse? _paymentResponse;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
    _initiatePayment();
  }

  /// Step 1: Initiate Payment
  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate user data
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw Exception('User email not found');
      }

      final response = await _paymentService.initiatePayment(
        orderId: widget.orderId,
        amount: widget.amount,
        customerId: user.uid,
        mobileNumber: _getMobileNumber(), // Get from user profile
        emailId: email,
        productDescription: widget.productDescription,
      );

      // LOG: API response from backend
      debugPrint('[PAYMENT UI] Initiation Response: ${response.success}, Error: ${response.error}');

      setState(() {
        _paymentResponse = response;
        _isLoading = false;
      });

      if (response.success) {
        // Payment initiated, now open ICICI payment gateway
        _openPaymentGateway(response);
      } else {
        final errorMsg = response.error ?? 'Payment initiation failed';
        debugPrint('[PAYMENT UI] Error: $errorMsg');
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Step 2: Open ICICI Payment Gateway (WebView)
  /// In real implementation, use webview_flutter or url_launcher
  Future<void> _openPaymentGateway(PaymentResponse response) async {
    // TODO: Implement WebView to open ICICI payment page
    // This is where user enters card/payment details
    // After payment, ICICI redirects to callback URL

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening payment gateway...'),
        duration: Duration(seconds: 2),
      ),
    );

    // After ICICI processes payment and redirects back:
    // 1. Check payment status
    await Future.delayed(Duration(seconds: 2));
    _checkPaymentStatus();
  }

  /// Step 3: Check Payment Status
  /// Call this after user returns from payment gateway
  Future<void> _checkPaymentStatus() async {
    if (_paymentResponse == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final statusResponse = await _paymentService.checkPaymentStatus(
        orderId: widget.orderId,
        customerId: user.uid,
      );

      if (statusResponse.success) {
        switch (statusResponse.status) {
          case 'SUCCESS':
            _showPaymentSuccessDialog(statusResponse);
            break;
          case 'FAILED':
            setState(() {
              _errorMessage = 'Payment failed. Please try again.';
            });
            break;
          case 'PENDING':
            // Still processing, check again in 5 seconds
            await Future.delayed(Duration(seconds: 5));
            _checkPaymentStatus();
            break;
        }
      } else {
        setState(() {
          _errorMessage = statusResponse.error ?? 'Status check failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking status: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show success dialog after successful payment
  void _showPaymentSuccessDialog(PaymentStatusResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: ${widget.orderId}'),
            SizedBox(height: 8),
            Text('Amount: ₹${response.amount?.toStringAsFixed(2)}'),
            SizedBox(height: 8),
            if (response.transactionId != null)
              Text('Transaction ID: ${response.transactionId}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close payment screen
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Example: Get mobile number from user profile
  /// In production, get this from Firestore user document
  String _getMobileNumber() {
    // TODO: Retrieve from user profile in Firestore
    // For now, return placeholder
    return '9900433466'; // Replace with actual user mobile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Payment Processing'), centerTitle: true),
      body: Center(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _buildSuccessState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Processing your payment...'),
        SizedBox(height: 16),
        Text('Order: ${widget.orderId}'),
        Text('Amount: ₹${widget.amount.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 64),
        SizedBox(height: 16),
        Text(
          'Payment Failed',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? 'Unknown error occurred',
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 32),
        ElevatedButton(
          onPressed: _initiatePayment,
          child: Text('Retry Payment'),
        ),
        SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 64),
        SizedBox(height: 16),
        Text(
          'Ready for Payment',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 32),
        Card(
          margin: EdgeInsets.all(32),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Order ID', widget.orderId),
                Divider(),
                _buildDetailRow(
                  'Amount',
                  '₹${widget.amount.toStringAsFixed(2)}',
                ),
                Divider(),
                _buildDetailRow('Description', widget.productDescription),
              ],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => _openPaymentGateway(_paymentResponse!),
          child: Text('Proceed to Payment'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ===== How to Use This Screen =====
/*
Navigate to payment screen:

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaymentProcessingScreen(
      orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      amount: 499.00,
      productDescription: '3-Month Premium Subscription',
    ),
  ),
);
*/
