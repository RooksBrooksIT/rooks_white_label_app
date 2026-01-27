import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_home_page.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_customerlogin_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AMCTrackMyService extends StatefulWidget {
  final String customerName;
  final String customerId;
  const AMCTrackMyService({
    super.key,
    required this.customerName,
    required this.customerId,
  });

  @override
  State<AMCTrackMyService> createState() => _AMCTrackMyServiceState();
}

class _AMCTrackMyServiceState extends State<AMCTrackMyService> {
  String _mapEngineerStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return 'Checking...';
    }
    final normalized = status.trim();
    switch (normalized.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'not assigned':
        return 'Not Assigned';
      case 'assigned':
        return 'Assigned';
      case 'in progress':
        return 'In Progress';
      case 'completed':
      case 'complete':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        // Capitalize first letter of each word for neat UI
        return normalized
            .split(' ')
            .map(
              (word) => word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1)
                  : '',
            )
            .join(' ');
    }
  }

  // Helper method for consistent info rows with icons
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String docId) {
    final bookingId = data['bookingId']?.toString() ?? 'N/A';
    final customerName = data['customerName'] ?? 'N/A';
    // final assignedEmployee = data['assignedEmployee'] ?? 'Not Assigned Yet';
    final message = data['message'] ?? '-';
    final mobileNumber = data['mobileNumber'] ?? '-';
    final jobType = data['JobType'] ?? '-';
    final categoryName = data['categoryName'] ?? '-';
    final deviceCondition = data['deviceCondition'] ?? '-';
    final deviceBrand = data['deviceBrand'] ?? '-';
    final description = data['description'] ?? '-';
    final amount = (data['amount'] != null)
        ? data['amount'].toString()
        : '0'; // fallback as string
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final customerID = (data['id'] ?? '-').toString();
    final String dateString = timestamp != null
        ? DateFormat(
            'MMM dd, yyyy - hh:mm a',
          ).format(timestamp.toDate().toLocal())
        : 'No Date';
    final rawStatus = data['engineerStatus'] ?? '';
    final statusInfo = _mapEngineerStatus(rawStatus);
    final bool isCompleted = statusInfo.toLowerCase() == 'completed';
    final bool hasFeedback =
        data['FeedBack'] != null && data['FeedBack'].toString().isNotEmpty;
    final adminStatus = data['adminStatus']?.toString().toLowerCase() ?? '';
    final bool isCancelled =
        adminStatus == 'canceled' || adminStatus == 'cancelled';
    final bool canCancel =
        !isCancelled &&
        !isCompleted &&
        statusInfo.toLowerCase() != 'in progress' &&
        statusInfo.toLowerCase() != 'completed';

    // Determine status color
    Color statusColor;
    IconData statusIcon;
    switch (statusInfo.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.access_time;
        break;
      case 'assigned':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.build;
        break;
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        break;
      case 'not assigned':
        statusColor = const Color(0xFFF44336);
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = const Color(0xFF757575);
        statusIcon = Icons.block;
        break;
      default:
        statusColor = const Color.fromARGB(255, 192, 149, 9);
        statusIcon = Icons.help;
    }

    final bookingIdText = bookingId.toString();

    // If ticket is cancelled, show a disabled card
    if (isCancelled) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
            color: Theme.of(context).disabledColor.withOpacity(0.05),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 20,
                          color: Theme.of(context).disabledColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Booking #$bookingId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            'Cancelled',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['Reason_cancel'] != null
                              ? 'Cancelled: ${data['Reason_cancel']}'
                              : 'This service request has been cancelled',
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isCompleted && !hasFeedback
            ? () {
                showDialog(
                  context: context,
                  builder: (ctx) => FeedbackDialog(
                    bookingId: bookingIdText,
                    documentId: docId,
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with Booking ID and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Booking #$bookingId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusInfo,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Feedback status message
                if (hasFeedback)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Feedback submitted: ${data['FeedBack']}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isCompleted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Feedback will be available once service is completed',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (hasFeedback || !isCompleted) const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.grey),
                const SizedBox(height: 12),

                // Customer and Employee Information
                _buildInfoRow('Customer ID', customerID, Icons.badge),
                _buildInfoRow('Customer', customerName, Icons.person),
                // _buildInfoRow(
                //   'Assigned To',
                //   assignedEmployee,
                //   Icons.engineering,
                // ),
                _buildInfoRow('Contact', mobileNumber, Icons.phone),

                const SizedBox(height: 12),

                // Service Details Section
                Row(
                  children: [
                    Icon(
                      Icons.build_circle,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Service Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _buildInfoRow('Job Type', jobType, Icons.work),
                // _buildInfoRow('Category', categoryName, Icons.category),
                _buildInfoRow(
                  'Device Brand',
                  deviceBrand,
                  Icons.branding_watermark,
                ),
                _buildInfoRow(
                  'Device Condition',
                  deviceCondition,
                  Icons.assessment,
                ),

                if (description.isNotEmpty && description != '-')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                if (message.isNotEmpty && message != '-')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Message:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.grey),
                const SizedBox(height: 12),

                // Footer with Amount and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.money, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                            Text(
                              '₹$amount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Created Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                            Text(
                              dateString,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Cancel Ticket Button (only show if ticket can be cancelled)
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text(
                        'Cancel Ticket',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.red.shade300,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => CancelTicketDialog(
                            bookingId: bookingIdText,
                            documentId: docId,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modified query to get all service requests for this customer
    // regardless of customerStatus, since we want to show engineerStatus
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = FirestoreService
        .instance
        .collection('Admin_details')
        .where('customerName', isEqualTo: widget.customerName)
        .where('id', isEqualTo: widget.customerId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track My Services',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/empty_box.json',
                    height: 180,
                    repeat: true,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No service tickets found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your service requests will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildTicketCard(doc.data(), doc.id);
            },
          );
        },
      ),
    );
  }
}

class CancelTicketDialog extends StatefulWidget {
  final String bookingId;
  final String documentId;

  const CancelTicketDialog({
    super.key,
    required this.bookingId,
    required this.documentId,
  });

  @override
  State<CancelTicketDialog> createState() => _CancelTicketDialogState();
}

class _CancelTicketDialogState extends State<CancelTicketDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _cancelTicket(BuildContext context) async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter reason for cancellation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.documentId)
          .update({
            'Reason_cancel': _reasonController.text.trim(),
            'adminStatus': 'Canceled',
            'engineerStatus': 'Cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

      // Close the dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancellation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              "Cancel Booking #${widget.bookingId}?",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3470),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please provide reason for cancellation:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for cancellation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0B3470)),
                ),
              ),
              onChanged: (value) {
                setState(() {}); // Rebuild to update button visibility
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _reasonController.text.trim().isEmpty || _isSubmitting
                        ? null
                        : () => _cancelTicket(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Confirm Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackDialog extends StatelessWidget {
  final String bookingId;
  final String documentId;

  const FeedbackDialog({
    super.key,
    required this.bookingId,
    required this.documentId,
  });

  Future<void> _submitFeedback(BuildContext context, String feedback) async {
    try {
      await FirestoreService.instance
          .collection('Admin_details')
          .doc(documentId)
          .update({'FeedBack': feedback});

      // Close the feedback dialog
      Navigator.of(context).pop();

      // Show confirmation dialog based on feedback type
      _showConfirmationDialog(context, feedback);
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(BuildContext context, String feedback) {
    String message;
    IconData icon;
    Color color;

    switch (feedback) {
      case "Good":
        message =
            "Thank you for your positive feedback! We're thrilled to hear you had a great experience with our service.";
        icon = Icons.emoji_emotions;
        color = Colors.green;
        break;
      case "Ok":
        message =
            "Thank you for your feedback. We appreciate your input and will work to improve our service for your next visit.";
        icon = Icons.sentiment_neutral;
        color = Colors.orange;
        break;
      case "Not Satisfied":
        message =
            "We sincerely apologize for the unsatisfactory experience. Our team will contact you shortly to address your concerns.";
        icon = Icons.sentiment_dissatisfied;
        color = Colors.red;
        break;
      default:
        message = "Thank you for your feedback!";
        icon = Icons.thumb_up;
        color = Colors.blue;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: color),
                const SizedBox(height: 16),
                Text(
                  "Thank You for Your Feedback!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Close", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Feedback for Booking #$bookingId",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3470),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How satisfied are you with the service?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Horizontal row of circular feedback buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Good feedback button
                Column(
                  children: [
                    InkWell(
                      onTap: () => _submitFeedback(context, "Good"),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: const Center(
                          child: Text('😊', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Good',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                // Ok feedback button
                Column(
                  children: [
                    InkWell(
                      onTap: () => _submitFeedback(context, "Ok"),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Center(
                          child: Text('😐', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ok',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                // Not Satisfied feedback button
                Column(
                  children: [
                    InkWell(
                      onTap: () => _submitFeedback(context, "Not Satisfied"),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Center(
                          child: Text('😞', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Not Satisfied',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Maybe Later",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AMCCustomerMainPage extends StatefulWidget {
  const AMCCustomerMainPage({super.key});

  @override
  State<AMCCustomerMainPage> createState() => _AMCCustomerMainPageState();
}

class _AMCCustomerMainPageState extends State<AMCCustomerMainPage> {
  String? userEmail;
  String userName = '';
  String customerId = '';
  String phoneNumber = '';
  late String dateTimeString;
  Timer? timer;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    updateDateTime();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateDateTime());

    loadUserData();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void updateDateTime() {
    final now = DateTime.now();
    final formatted = DateFormat('EEEE, MMM d, yyyy hh:mm:ss a').format(now);
    setState(() {
      dateTimeString = formatted;
    });
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      setState(() {
        userEmail = email;
      });
      if (email != null) {
        final query = await FirestoreService.instance
            .collection('AMC_user')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final userData = query.docs.first.data();
          setState(() {
            userName = userData['name'] ?? '';
            customerId = userData['Id'] ?? '';
            phoneNumber = userData['phonenumber']?.toString() ?? '';
          });
        } else {
          setState(() {
            userName = '';
            customerId = '';
            phoneNumber = '';
          });
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        userName = '';
        customerId = '';
        phoneNumber = '';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleLogout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        // Navigate to the AMC login page and remove all previous routes so user cannot go back
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AMCLoginPage()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: const Text(
          'AMC Customer Portal',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => handleLogout(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B3470)),
            )
          : Column(
              children: [
                // User Info Section - Fixed to show both name and phone number properly
                if (userName.isNotEmpty || phoneNumber.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE8F4FD),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Name
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 20,
                              color: Color(0xFF0B3470),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hello, $userName!',
                              style: const TextStyle(
                                color: Color(0xFF0B3470),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Phone Number
                        if (phoneNumber.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 18,
                                color: Color(0xFF0B3470),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Phone: $phoneNumber',
                                style: const TextStyle(
                                  color: Color(0xFF0B3470),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                // Date Time Section
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF5F9FF),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.build_circle,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateTimeString,
                        style: const TextStyle(
                          color: Color(0xFF0B3470),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Email display
                            if (userEmail != null)
                              Align(
                                alignment: Alignment.topRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(
                                      Icons.email,
                                      size: 14,
                                      color: Color(0xFF0B3470),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      userEmail!,
                                      style: const TextStyle(
                                        color: Color(0xFF0B3470),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),

                            // Lottie animation
                            Lottie.asset(
                              'assets/phone_login.json',
                              height: 180,
                              repeat: true,
                            ),
                            const SizedBox(height: 16),

                            // Welcome text
                            const Text(
                              'Welcome to Our AMC Customer Portal!',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B3470),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'We\'re here to provide you with reliable device maintenance and seamless service support. Add your devices or track your service requests quickly and easily.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Action buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add Device Services'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B3470),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AmcCustomerHomePage(
                                        customerId: customerId,
                                        customerName: userName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.track_changes),
                                label: const Text('Track My Services'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: userName.isNotEmpty
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AMCTrackMyService(
                                                  customerName: userName,
                                                  customerId: customerId,
                                                ),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
