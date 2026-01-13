import 'package:flutter/material.dart';
import 'payment_screen.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  int selectedPlanIndex = 1; // Default: Gold (Index 1)

  // Plan data
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Silver Plan',
      'price': 199,
      'originalPrice': 299,
      'subtitle': 'Best for small teams & basic usage',
      'features': ['0-30 Customers', '0-5 Engineers', 'Web support'],
      'color': const Color(0xFFE0E0E0), // Silver-ish
    },
    {
      'name': 'Gold Plan',
      'price': 799,
      'originalPrice': 999,
      'subtitle': 'Ideal for growing businesses',
      'features': [
        '0-100 Customers',
        'Up to 30 Photos & PDF Uploads',
        'Geo Location, Attendance, Barcode Available',
        '0-10 Engineer',
        'Web support',
      ],
      'color': const Color(0xFFFFD700), // Gold
    },
    {
      'name': 'Platinum Plan',
      'price': 1999,
      'originalPrice': 2999,
      'subtitle': 'Best for enterprises & unlimited usage',
      'features': [
        'Unlimited Customers',
        'Unlimited Photos & PDF Uploads',
        'Geo Location, Attendance, Barcode Available',
        'Unlimited Engineer',
        'Web support',
      ],
      'color': const Color(0xFFE5E4E2), // Platinum
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F7FA), // Very light grey/white
              Color(0xFFE8F0FE), // Light blue tint
              Color(0xFFD0E1F9), // Deeper blue tint
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            'CHOOSE WHAT FITS YOU',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose the plan that suits your Workflow best',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance spacing
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main Plan Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildMainCard(plans[selectedPlanIndex]),
                ),
              ),

              const SizedBox(height: 30),

              // Bottom Selectors
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(plans.length, (index) {
                    return _buildBottomSelector(index);
                  }),
                ),
              ),

              const SizedBox(height: 30),

              // Subscribe Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      _handlePlanSelection(context, plans[selectedPlanIndex]);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1), // Dark Blue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Subscribe now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> plan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              plan['name'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${plan['price']}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${plan['originalPrice']}',
                  style: const TextStyle(
                    fontSize: 20,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Text(
              '/Month',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              'Applicable for 12 and 24 months only',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Text(
              plan['subtitle'],
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: plan['features'].length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 20,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            plan['features'][index],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSelector(int index) {
    final plan = plans[index];
    final isSelected = selectedPlanIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlanIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:
            MediaQuery.of(context).size.width *
            0.26, // Roughly 1/3 minus padding
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D47A1) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D47A1).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plan['name'],
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '₹${plan['price']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              '/Month',
              style: TextStyle(fontSize: 8, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              'Best for small teams & basic usage', // Truncate or use subtitle in full card
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlanSelection(
    BuildContext context,
    Map<String, dynamic> selectedPlan,
  ) {
    // Navigate to Payment Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          planName: selectedPlan['name'],
          price: selectedPlan['price'],
          originalPrice: selectedPlan['originalPrice'],
          isYearly: true, // Specific constraint from UI text
        ),
      ),
    );
  }
}
