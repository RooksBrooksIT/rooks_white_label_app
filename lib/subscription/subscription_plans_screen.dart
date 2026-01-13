import 'package:flutter/material.dart';
import 'branding_customization_screen.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  int selectedPlanIndex = 2; // Default: Pro (now at index 2)
  bool isYearly = true; // Toggle for yearly/monthly billing

  // Plan data
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Try Demo',
      'monthlyPrice': 0,
      'yearlyPrice': 0,
      'originalYearlyPrice': 0,
      'subtitle': 'Experience all features',
      'features': [
        'Full access to all features',
        'No credit card required',
        'Cancel anytime',
        'After 7 days, choose a paid plan',
      ],
      'color': Colors.green,
    },
    {
      'name': 'Essential',
      'monthlyPrice': 999,
      'yearlyPrice': 9990,
      'originalYearlyPrice': 11988,
      'subtitle': 'For small teams & startups',
      'features': [
        'Service request management',
        'Basic ticket tracking',
        'Email notifications',
        'Standard support',
      ],
      'color': Colors.blue,
    },
    {
      'name': 'Pro',
      'monthlyPrice': 1999,
      'yearlyPrice': 19190,
      'originalYearlyPrice': 23988,
      'subtitle': 'Most popular for growing businesses',
      'features': [
        'Everything in Essential',
        'Engineer assignment',
        'Priority support',
        'Service history & analytics',
        'Custom branding',
      ],
      'color': Colors.deepPurple,
    },
    {
      'name': 'Business',
      'monthlyPrice': 3499,
      'yearlyPrice': 34990,
      'originalYearlyPrice': 41988,
      'subtitle': 'For large organizations & enterprises',
      'features': [
        'Everything in Pro',
        'Unlimited users & technicians',
        'Advanced analytics & reporting',
        'Dedicated account manager',
        'Custom integrations & API access',
        'White-label solution',
        '24/7 Priority phone support',
      ],
      'color': Colors.green.shade700,
    },
  ];

  // Comparison data
  final List<Map<String, dynamic>> comparisonData = [
    {
      'feature': 'Service Request Management',
      'essential': true,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Basic Ticket Tracking',
      'essential': true,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Email Notifications',
      'essential': true,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Standard Support',
      'essential': true,
      'pro': false,
      'business': false,
    },
    {
      'feature': 'Engineer Assignment',
      'essential': false,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Priority Support',
      'essential': false,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Service History & Analytics',
      'essential': false,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Custom Branding',
      'essential': false,
      'pro': true,
      'business': true,
    },
    {
      'feature': 'Unlimited Users',
      'essential': false,
      'pro': false,
      'business': true,
    },
    {
      'feature': 'Advanced Reporting',
      'essential': false,
      'pro': false,
      'business': true,
    },
    {
      'feature': 'Dedicated Account Manager',
      'essential': false,
      'pro': false,
      'business': true,
    },
    {
      'feature': 'Custom Integrations',
      'essential': false,
      'pro': false,
      'business': true,
    },
    {
      'feature': 'White-label Solution',
      'essential': false,
      'pro': false,
      'business': true,
    },
    {
      'feature': '24/7 Phone Support',
      'essential': false,
      'pro': false,
      'business': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPlan = plans[selectedPlanIndex];
    final price = isYearly
        ? selectedPlan['yearlyPrice']
        : selectedPlan['monthlyPrice'];
    final originalPrice = isYearly ? selectedPlan['originalYearlyPrice'] : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // FLOATING CTA BUTTON
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // Confirm and then navigate based on selected plan
            _confirmPlanSelection(context, selectedPlan);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            selectedPlanIndex == 0
                ? 'Start Free Demo'
                : 'Continue with Selected Plan',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),

      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows, size: 24),
            onPressed: () {
              _showComparisonTable(context);
            },
            tooltip: 'Compare Plans',
          ),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 90,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Plans',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select a plan that fits your business needs',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Billing Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 16,
                                color: !isYearly
                                    ? Colors.deepPurple
                                    : Colors.grey,
                                fontWeight: !isYearly
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Switch(
                              value: isYearly,
                              onChanged: (value) {
                                setState(() {
                                  isYearly = value;
                                });
                              },
                              activeThumbColor: Colors.deepPurple,
                            ),
                            const SizedBox(width: 20),
                            Text(
                              'Yearly',
                              style: TextStyle(
                                fontSize: 16,
                                color: isYearly
                                    ? Colors.deepPurple
                                    : Colors.grey,
                                fontWeight: isYearly
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isYearly)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                'Save up to 20% with yearly billing!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // PLANS - Dynamically generated from plans list
                      ...List.generate(plans.length, (index) {
                        final plan = plans[index];
                        final isSelected = selectedPlanIndex == index;
                        final isDemo = index == 0;

                        if (isDemo) {
                          return Column(
                            children: [
                              _planCard(
                                index: index,
                                title: plan['name'],
                                price: 'Free for 7 days',
                                subtitle: plan['subtitle'],
                                features: plan['features'],
                                color: plan['color'],
                                isSelected: isSelected,
                                isDemo: true,
                              ),
                              if (index < plans.length - 1) ...[
                                const SizedBox(height: 8),
                                const Divider(thickness: 1),
                                const SizedBox(height: 8),
                              ],
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _planCard(
                                index: index,
                                title: plan['name'],
                                price: isYearly
                                    ? '₹${plan['yearlyPrice']} / year'
                                    : '₹${plan['monthlyPrice']} / month',
                                originalPrice: isYearly
                                    ? '₹${plan['originalYearlyPrice']}'
                                    : null,
                                savings: isYearly
                                    ? index == 2
                                          ? 'Save 20%'
                                          : 'Save 17%'
                                    : null,
                                subtitle: plan['subtitle'],
                                features: plan['features'],
                                color: plan['color'],
                                isSelected: isSelected,
                                isPopular: index == 2, // Pro plan is popular
                                isYearly: isYearly,
                              ),
                              if (index < plans.length - 1)
                                const SizedBox(height: 20),
                            ],
                          );
                        }
                      }),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmPlanSelection(
    BuildContext context,
    Map<String, dynamic> selectedPlan,
  ) async {
    final isDemo = selectedPlan['name'] == 'Try Demo';
    if (isDemo) {
      _startFreeDemo(context);
      return;
    }

    final price = isYearly
        ? selectedPlan['yearlyPrice']
        : selectedPlan['monthlyPrice'];
    final billingLabel = isYearly ? 'yearly' : 'monthly';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Plan'),
        content: Text(
          'Proceed with ${selectedPlan['name']} plan on $billingLabel billing for ₹$price?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handlePlanSelection(context, selectedPlan);
    }
  }

  void _handlePlanSelection(
    BuildContext context,
    Map<String, dynamic> selectedPlan,
  ) {
    if (selectedPlanIndex == 0) {
      _startFreeDemo(context);
    } else {
      // Navigate to branding customization screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BrandingCustomizationScreen(
            selectedPlan: selectedPlan,
            isYearly: isYearly,
          ),
        ),
      );
    }
  }

  void _startFreeDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Free Demo'),
        content: const Text(
          'Your 7-day free trial has started! You now have full access to all features. '
          'You can cancel anytime before the trial ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo started successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Continue to App'),
          ),
        ],
      ),
    );
  }

  void _showComparisonTable(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plan Comparison',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Plan Headers
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: const Text(
                      'Features',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _planHeader('Essential', Colors.blue),
                        _planHeader('Pro', Colors.deepPurple, isPopular: true),
                        _planHeader('Business', Colors.green.shade700),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Comparison Table
            Expanded(
              child: ListView.builder(
                itemCount: comparisonData.length,
                itemBuilder: (context, index) {
                  final feature = comparisonData[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: index.isEven ? Colors.white : Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.3,
                          child: Text(
                            feature['feature'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _featureCell(feature['essential']),
                              _featureCell(feature['pro']),
                              _featureCell(feature['business']),
                            ],
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

  Widget _planHeader(String title, Color color, {bool isPopular = false}) {
    return Column(
      children: [
        if (isPopular)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'POPULAR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        if (isPopular) const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _featureCell(bool isAvailable) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
      ),
      child: Icon(
        isAvailable ? Icons.check : Icons.close,
        size: 16,
        color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Widget _planCard({
    required int index,
    required String title,
    required String price,
    required String subtitle,
    required List<String> features,
    required Color color,
    bool isSelected = false,
    bool isPopular = false,
    bool isDemo = false,
    String? originalPrice,
    String? savings,
    bool? isYearly,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlanIndex = index;
        });
        if (index == 0) {
          _startFreeDemo(context);
        } else {
          _confirmPlanSelection(context, plans[index]);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isDemo ? 10 : 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDemo ? Colors.green.shade50 : Colors.deepPurple.shade50)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDemo ? Colors.green : Colors.deepPurple)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDemo)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FREE TRIAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            if (isPopular && !isDemo)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Radio button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isDemo ? Colors.green : Colors.deepPurple)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDemo ? Colors.green : Colors.deepPurple,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Price with savings information
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDemo ? Colors.green.shade700 : Colors.deepPurple,
                  ),
                ),

                if (savings != null && originalPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            originalPrice,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              savings,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isYearly == true
                            ? 'Billed annually (${_calculateMonthlyEquivalent(price)})'
                            : 'Billed monthly',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: isDemo ? Colors.green.shade600 : Colors.deepPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
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

  String _calculateMonthlyEquivalent(String yearlyPrice) {
    final regex = RegExp(r'₹([\d,]+)');
    final match = regex.firstMatch(yearlyPrice);

    if (match != null) {
      final priceStr = match.group(1)!.replaceAll(',', '');
      final price = int.tryParse(priceStr) ?? 0;
      final monthly = price / 12;
      return '₹${monthly.toStringAsFixed(0)}/month';
    }

    return '';
  }
}
