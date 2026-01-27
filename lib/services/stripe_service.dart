import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // TODO: Replace with your actual Stripe Publishable Key
  // You can find this in the Stripe Dashboard -> Developers -> API Keys
  static const String stripePublishableKey =
      'pk_test_your_publishable_key_here';

  // TODO: Replace with your backend URL that creates a PaymentIntent
  // Example: 'https://your-cloud-function-url.com/create-payment-intent'
  static const String paymentApiUrl =
      'https://api.stripe.com/v1/payment_intents';

  // TODO: Ideally, you should not store your Secret Key in the app.
  // This is only for testing/demonstration purposes if you don't have a backend yet.
  // In production, you MUST generate the PaymentIntent on your backend server.
  static const String _testSecretKey = 'sk_test_your_secret_key_here';

  Future<void> initialize() async {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  Future<bool> makePayment({
    required String amount,
    required String currency,
  }) async {
    try {
      // 1. Create Payment Intent (on server or using direct API for testing)
      final paymentIntent = await _createPaymentIntent(amount, currency);
      if (paymentIntent == null) return false;

      final clientSecret = paymentIntent['client_secret'];
      final customerId = paymentIntent['customer'];
      final ephemeralKey = paymentIntent['ephemeralKey'];

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Rooks App',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          // billingDetails: const BillingDetails(name: 'Flutter Stripe'),
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Colors.deepPurple),
          ),
        ),
      );

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. If we are here, payment is successful
      return true;
    } on StripeException catch (e) {
      debugPrint('Stripe Error: $e');
      if (e.error.code == FailureCode.Canceled) {
        // User canceled
        return false;
      }
      rethrow;
    } catch (e) {
      debugPrint('Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent(
    String amount,
    String currency,
  ) async {
    try {
      // NOTE: This direct API call is for DEMO purposes only.
      // Use a backend server to create PaymentIntents in production.

      final Map<String, dynamic> body = {
        'amount': _calculateAmount(amount),
        'currency': currency,
        'payment_method_types[]': 'card',
      };

      // Calling Stripe API directly (only for testing with test keys)
      final response = await http.post(
        Uri.parse(paymentApiUrl),
        headers: {
          'Authorization': 'Bearer $_testSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      return null;
    }
  }

  String _calculateAmount(String amount) {
    // Amount must be in cents/smallest unit
    final parsed = int.tryParse(amount) ?? 0;
    return (parsed * 100)
        .toString(); // Assuming amount is in standard currency like USD/INR
  }
}
