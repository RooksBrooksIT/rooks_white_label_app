import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/icici_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ThemeService.instance.databaseName;
    final appId = ThemeService.instance.appName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions & Refunds'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Txn ID or Customer Name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.instance
                  .collection(
                    'payment_transactions',
                    tenantId: tenantId,
                    appId: appId,
                  )
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No transactions found.'));
                }

                // Filter locally for search query
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final txnId = (data['merchantTxnNo'] ?? '')
                      .toString()
                      .toLowerCase();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  final amount = (data['amount'] ?? '').toString();

                  return txnId.contains(_searchQuery) ||
                      status.contains(_searchQuery) ||
                      amount.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No matching transactions.'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final merchantTxnNo = data['merchantTxnNo'] ?? 'Unknown';
                    final amount = data['amount'] ?? '0.00';
                    final status = data['status'] ?? 'UNKNOWN';
                    final timestamp = (data['timestamp'] as Timestamp?)
                        ?.toDate();
                    final formattedDate = timestamp != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp)
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Text(
                              '₹$amount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(status),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Txn ID: $merchantTxnNo'),
                            Text(formattedDate),
                            if (data['paymentMethod'] != null)
                              Text('Method: ${data['paymentMethod']}'),
                          ],
                        ),
                        trailing:
                            (status == 'SUCCESS' || status == 'UAT_SIMULATED')
                            ? OutlinedButton(
                                onPressed: () => _confirmRefund(
                                  context,
                                  merchantTxnNo,
                                  amount,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text('Refund'),
                              )
                            : (status == 'REFUNDED' ||
                                  status == 'REFUND_INITIATED')
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.orange,
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'UAT_SIMULATED':
        color = Colors.green;
        break;
      case 'FAILED':
      case 'CANCELLED':
        color = Colors.red;
        break;
      case 'REFUNDED':
        color = Colors.orange;
        break;
      case 'INITIATED':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _confirmRefund(
    BuildContext context,
    String merchantTxnNo,
    String amount,
  ) async {
    final shouldRefund = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Text(
          'Are you sure you want to initiate a refund for Txn #$merchantTxnNo of ₹$amount?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Refund Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldRefund == true && mounted) {
      _processRefund(merchantTxnNo, amount);
    }
  }

  Future<void> _processRefund(String merchantTxnNo, String amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await IciciService.instance.initiateRefund(
        merchantTxnNo: merchantTxnNo,
        amount: amount,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result != null &&
          (result['status'] == '0' || result['status'] == 'SUCCESS')) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund initiated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Update status in Firestore
        final tenantId = ThemeService.instance.databaseName;
        final appId = ThemeService.instance.appName;

        await FirestoreService.instance
            .collection(
              'payment_transactions',
              tenantId: tenantId,
              appId: appId,
            )
            .doc(merchantTxnNo)
            .update({
              'status': 'REFUNDED',
              'refundTimestamp': FieldValue.serverTimestamp(),
              'refundData': result,
            });
      } else {
        // Evaluate failure
        final msg = result?['message'] ?? 'Refund failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
