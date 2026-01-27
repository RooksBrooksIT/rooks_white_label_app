import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'transaction_completed_screen.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';


class CardDetailsScreen extends StatefulWidget {
  final int paymentAmount;
  final String planName;
  final bool isYearly;

  const CardDetailsScreen({
    super.key,
    required this.paymentAmount,
    required this.planName,
    this.isYearly =
        false, // Default to false if not passed (simplify for now, or require it)
  });

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  String _cardNumber = '0000 0000 0000 0000';
  String _expiryDate = 'MM/YY';
  String _cardHolderName = 'CARD HOLDER';

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(() {
      setState(() {
        _cardNumber = _cardNumberController.text.isEmpty
            ? '0000 0000 0000 0000'
            : _cardNumberController.text;
      });
    });
    _expiryController.addListener(() {
      setState(() {
        _expiryDate = _expiryController.text.isEmpty
            ? 'MM/YY'
            : _expiryController.text;
      });
    });
    _cardHolderController.addListener(() {
      setState(() {
        _cardHolderName = _cardHolderController.text.isEmpty
            ? 'CARD HOLDER'
            : _cardHolderController.text.toUpperCase();
      });
    });
    /*_cvvController.addListener(() {
      setState(() {
        _cvv = _cvvController.text;
      });
    });*/
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeService.instance.defaultTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Add Card'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildRealisticCard(),
              const SizedBox(height: 40),
              _buildCardForm(),
              const SizedBox(height: 32),
              _buildPayButton(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your payment information is secure',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealisticCard() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1F38), // Deep Dark Blue
            const Color(0xFF2C3E50), // Slate
            const Color(0xFF4CA1AF), // Teal-ish highlight
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Noise/Texture Pattern
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Chip + Contactless
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // EMV Chip
                    Container(
                      width: 50,
                      height: 35,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37), // Gold/Chip color
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE5C16C), Color(0xFFB58E28)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 17,
                            child: Container(height: 1, color: Colors.black12),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 16,
                            child: Container(width: 1, color: Colors.black12),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 16,
                            child: Container(width: 1, color: Colors.black12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.wifi, color: Colors.white54, size: 28),
                  ],
                ),

                // Card Number
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _cardNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontFamily:
                          'Courier', // Monospace font simulates embossing
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Row: Details + Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CARD HOLDER',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cardHolderName.length > 20
                              ? '${_cardHolderName.substring(0, 18)}...'
                              : _cardHolderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXPIRES',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _expiryDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    // MasterCard Logo (Simplified circles)
                    SizedBox(
                      width: 50,
                      height: 30,
                      child: Stack(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            left: 20,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      children: [
        _buildTextField(
          label: 'Card Number',
          icon: Icons.credit_card,
          controller: _cardNumberController,
          hint: '0000 0000 0000 0000',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberFormatter(),
          ],
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Card Holder Name',
          icon: Icons.person_outline,
          controller: _cardHolderController,
          hint: 'JOHN DOE',
          inputFormatters: [LengthLimitingTextInputFormatter(26)],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Expiry Date',
                icon: Icons.calendar_today,
                controller: _expiryController,
                hint: 'MM/YY',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _ExpiryDateFormatter(),
                ],
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: 'CVV',
                icon: Icons.lock_outline,
                controller: _cvvController,
                hint: '123',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            inputFormatters: inputFormatters,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: Colors.grey.shade500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        onPressed: () {
          // Simulate Payment
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing payment...')),
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionCompletedScreen(
                    planName: widget.planName,
                    isYearly: widget.isYearly,
                    amountPaid: widget.paymentAmount,
                    paymentMethod: 'Card',
                    transactionId:
                        'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                    timestamp: DateTime.now(),
                  ),
                ),
              );
            }
          });
        },
        child: Text(
          'Pay ₹${widget.paymentAmount}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Formatters

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    String inputData = newValue.text;
    StringBuffer buffer = StringBuffer();

    for (var i = 0; i < inputData.length; i++) {
      buffer.write(inputData[i]);
      int index = i + 1;
      if (index % 4 == 0 && inputData.length != index) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var newText = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != newText.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
