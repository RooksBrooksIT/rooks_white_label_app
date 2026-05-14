import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';

/// Result returned by the WebView after the payment flow completes.
class IciciPaymentResult {
  final bool success;
  final String? message;
  final Map<String, String>? queryParams;

  const IciciPaymentResult({
    required this.success,
    this.message,
    this.queryParams,
  });
}

/// Full-screen WebView for the ICICI Payment Gateway.
///
/// Loads the payment URL and intercepts navigation to [returnUrl]
/// to determine whether the payment succeeded or was cancelled.
class IciciPaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String merchantTxnNo;
  final String returnUrl;

  const IciciPaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.merchantTxnNo,
    required this.returnUrl,
  });

  @override
  State<IciciPaymentWebViewScreen> createState() =>
      _IciciPaymentWebViewScreenState();
}

class _IciciPaymentWebViewScreenState extends State<IciciPaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0;
  StreamSubscription<DocumentSnapshot>? _txnSubscription;

  bool get _isUpiIntent => widget.paymentUrl.toLowerCase().startsWith('upi://') ||
                           widget.paymentUrl.toLowerCase().startsWith('gpay://') ||
                           widget.paymentUrl.toLowerCase().startsWith('phonepe://') ||
                           widget.paymentUrl.toLowerCase().startsWith('paytmmp://');

  @override
  void initState() {
    super.initState();
    if (!_isUpiIntent) {
      _initWebView();
    } else {
      _launchUpiIntent();
    }
    _listenToTransactionStatus();
  }

  void _listenToTransactionStatus() {
    _txnSubscription = IciciService.instance
        .streamTransactionStatus(widget.merchantTxnNo)
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final status = data['status'];
      if (status == 'SUCCESS') {
        _txnSubscription?.cancel();
        Navigator.pop(
          context,
          const IciciPaymentResult(
            success: true,
            message: 'Payment completed successfully',
          ),
        );
      } else if (status == 'FAILED') {
        _txnSubscription?.cancel();
        Navigator.pop(
          context,
          IciciPaymentResult(
            success: false,
            message: data['errorMsg'] ?? 'Payment failed',
          ),
        );
      }
    });
  }

  void _launchUpiIntent() async {
    final uri = Uri.parse(widget.paymentUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback or error handling
        debugPrint('Cannot launch UPI URL');
      }
    } catch (e) {
      debugPrint('Error launching UPI Intent: $e');
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _txnSubscription?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            debugPrint('WebView navigating to: ${request.url}');

            // 1. Intercept navigation to the return URL
            if (_isReturnUrl(request.url)) {
              debugPrint('Return URL detected: ${request.url}');
              _handleReturnUrl(request.url);
              return NavigationDecision.prevent;
            }

            // 2. Handle UPI / GPay / External Intent Schemes
            final url = request.url.toLowerCase();
            if (url.startsWith('upi://') ||
                url.startsWith('phonepe://') ||
                url.startsWith('paytmmp://') ||
                url.startsWith('gpay://') ||
                url.startsWith('tez://') || // Google Pay
                url.startsWith('intent://') ||
                url.startsWith('whatsapp://')) {
              debugPrint('External intent scheme detected: $url');
              try {
                final uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  debugPrint('Successfully launched external application');
                } else {
                  debugPrint('Could not launch external application for: $url');
                  // For intent:// schemes on Android, they need special handling
                  // but url_launcher usually handles basic upi:// fine.
                }
              } catch (e) {
                debugPrint('Error launching external URL: $e');
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            debugPrint('WebView page started: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            debugPrint('WebView page finished: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }

            // Also check if current URL is the return URL
            // (in case redirect happened without triggering onNavigationRequest)
            if (_isReturnUrl(url)) {
              _handleReturnUrl(url);
            }
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'WebView error: ${error.errorCode} - ${error.description}',
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Check if the given URL matches the configured return URL.
  bool _isReturnUrl(String url) {
    final returnUri = Uri.parse(widget.returnUrl);
    final currentUri = Uri.parse(url);

    // Match by host and path (ignoring query parameters)
    return currentUri.host == returnUri.host &&
        currentUri.path == returnUri.path;
  }

  /// Extract query parameters from the return URL and pop back with result.
  void _handleReturnUrl(String url) {
    final uri = Uri.parse(url);
    final queryParams = uri.queryParameters;

    debugPrint('Return URL query params: $queryParams');

    // Check for known success indicators from ICICI
    final status =
        queryParams['status'] ??
        queryParams['txnStatus'] ??
        queryParams['Status'] ??
        queryParams['RESPONSE_CODE'] ??
        '';

    final isSuccess =
        status.toUpperCase() == 'SUCCESS' ||
        status.toUpperCase() == 'APPROVED' ||
        status.toUpperCase() == 'TXN_SUCCESS' ||
        status == '0' ||
        status == '00' ||
        status == 'P1000';

    if (mounted) {
      Navigator.pop(
        context,
        IciciPaymentResult(
          success: isSuccess,
          message:
              queryParams['message'] ??
              queryParams['statusMessage'] ??
              (isSuccess ? 'Payment completed' : 'Payment was not completed'),
          queryParams: queryParams.isNotEmpty
              ? Map<String, String>.from(queryParams)
              : null,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    // Check if WebView can go back (only if not UPI intent)
    if (!_isUpiIntent && await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }

    // Show confirmation dialog before cancelling payment
    if (!mounted) return true;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this payment? '
          'Your transaction will not be completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Continue Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      Navigator.pop(
        context,
        const IciciPaymentResult(
          success: false,
          message: 'Payment cancelled by user',
        ),
      );
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'ICICI Payment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: _onWillPop,
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1A237E), // Brand Blue
                    ),
                  ),
                )
              : null,
        ),
        body: _isUpiIntent
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF1A237E)),
                    const SizedBox(height: 24),
                    const Text(
                      'Waiting for payment...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please complete the payment in your UPI app.',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton(
                      onPressed: () => _launchUpiIntent(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        side: const BorderSide(color: Color(0xFF1A237E)),
                      ),
                      child: const Text(
                        'Re-open UPI App',
                        style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading && _loadingProgress < 0.3)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF1A237E)),
                          SizedBox(height: 16),
                          Text(
                            'Loading payment page...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
