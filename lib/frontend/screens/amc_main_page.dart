import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:subscription_rooks_app/frontend/screens/amc_customerlogin_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_createtickets_devicetype.dart';
import 'package:flutter/services.dart';

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
  // Banner state
  bool showBanner = false;
  String bannerMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 6,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        ),
        title: Text(
          ThemeService.instance.appName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (showBanner)
            MaterialBanner(
              content: Text(
                bannerMessage,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              backgroundColor: Colors.green.shade700,
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      showBanner = false;
                    });
                  },
                  child: const Text(
                    'DISMISS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.instance
                  .collection('Admin_details')
                  .where('customerName', isEqualTo: widget.customerName)
                  .where('id', isEqualTo: widget.customerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Lottie.asset(
                      'assets/loading_animation.json',
                      width: 110,
                      repeat: true,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load tickets.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red.shade700,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                          'No service tickets found.',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }
                final tickets = snapshot.data!.docs;
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final data = tickets[index].data();
                    final documentId = tickets[index].id;
                    return _buildTicketCard(data, documentId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String documentId) {
    final cardColor = Theme.of(context).cardColor;
    final canceledCardColor = Theme.of(context).disabledColor.withOpacity(0.1);
    final bookingId = data['bookingId'] ?? 'N/A';
    final customerName = data['customerName'] ?? 'N/A';
    final customerId = data['id'] ?? 'Not Assigned Yet';
    final message = data['message'] ?? '-';
    final mobileNumber = data['mobileNumber'] ?? '-';
    final jobType = data['JobType'] ?? '-';
    final deviceCondition = data['deviceCondition'] ?? '-';
    final deviceBrand = data['deviceBrand'] ?? '-';
    final description = data['description'] ?? '-';
    final amount = data['amount']?.toString() ?? '0';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final feedback = data['FeedBack'] ?? '';
    final rawStatus = data['engineerStatus'] ?? '';
    final adminStatus = data['adminStatus']?.toString().toLowerCase() ?? '';
    final isCanceled = adminStatus == 'canceled' || adminStatus == 'cancelled';
    final statusInfo = _mapEngineerStatus(rawStatus);
    final isCompleted = statusInfo.label.toLowerCase() == 'completed';
    final hasFeedback = feedback.toString().isNotEmpty;

    return GestureDetector(
      onTap: isCompleted && !hasFeedback && !isCanceled
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => FeedbackDialog(
                  bookingId: bookingId.toString(),
                  documentId: documentId,
                ),
              );
            }
          : null,
      child: Card(
        color: isCanceled ? canceledCardColor : cardColor,
        elevation: isCanceled ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: isCanceled ? Colors.grey : Colors.grey.shade200,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt,
                    color: isCanceled
                        ? Colors.grey.shade700
                        : Theme.of(context).primaryColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Booking ID: $bookingId",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isCanceled
                            ? Theme.of(context).disabledColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCanceled)
                    _buildStatusChip('Canceled', Colors.red.shade600)
                  else
                    _buildStatusChip(statusInfo.label, statusInfo.color),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    color: isCanceled
                        ? Colors.grey.shade700
                        : Theme.of(context).primaryColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Your ID: $customerId",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isCanceled
                            ? Theme.of(context).disabledColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildDetailRow(
                Icons.person_outline,
                'Customer',
                customerName,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.message_outlined,
                'Message',
                message,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.phone_android_rounded,
                'Mobile',
                mobileNumber,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.work_outlined,
                'Job Type',
                jobType,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.devices_other_outlined,
                'Device Condition',
                deviceCondition,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.branding_watermark_outlined,
                'Device Brand',
                deviceBrand,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.description_outlined,
                'Description',
                description,
                isCanceled,
              ),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Created On',
                _formatTimestamp(timestamp),
                isCanceled,
              ),

              if (isCanceled && (data['Reason_cancel'] != null))
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancellation Note:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              data['Reason_cancel'].toString(),
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (hasFeedback)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCanceled
                        ? Colors.grey.shade300
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCanceled ? Colors.grey : Colors.green.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.feedback_outlined,
                        color: isCanceled
                            ? Colors.grey.shade700
                            : Colors.green.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Feedback:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCanceled
                                    ? Colors.grey.shade800
                                    : Colors.green.shade800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              feedback,
                              style: TextStyle(
                                color: isCanceled
                                    ? Colors.grey.shade700
                                    : Colors.green.shade700,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (isCompleted && !hasFeedback && !isCanceled)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap anywhere on this card to provide your feedback',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!isCompleted && !isCanceled)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Feedback will be available once the status is "Completed"',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Cancel Ticket Button
              if (!isCanceled &&
                  !isCompleted &&
                  rawStatus.toLowerCase() != 'in progress')
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => CancelTicketDialog(
                          bookingId: bookingId.toString(),
                          documentId: documentId,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cancel_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cancel Ticket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              Text(
                'Bill Amount :',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isCanceled
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹$amount',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isCanceled
                      ? Colors.grey.shade700
                      : const Color.fromARGB(255, 13, 116, 18),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String content,
    bool isCanceled,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isCanceled
                ? Colors.grey.shade600
                : Theme.of(context).primaryColor.withOpacity(0.85),
            size: 20,
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 110,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCanceled
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: isCanceled ? Colors.grey.shade700 : Colors.black54,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  _StatusInfo _mapEngineerStatus(String status) {
    final lowerStatus = status.toLowerCase().trim();
    switch (lowerStatus) {
      case 'complete':
      case 'completed':
        return _StatusInfo('Completed', Colors.green.shade600);
      case 'assigned':
        return _StatusInfo('Assigned', Colors.blue.shade600);
      case 'in progress':
        return _StatusInfo('In Progress', Colors.orange.shade700);
      case 'pending':
        return _StatusInfo('Pending', Colors.amber.shade700);
      case 'not assigned':
        return _StatusInfo('Not Assigned', Colors.red.shade700);
      case 'cancelled':
      case 'canceled':
        return _StatusInfo('Cancelled', Colors.grey.shade600);
      default:
        // Capitalize first letter if it's unknown
        String formatted = status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1)
            : 'Unknown';
        return _StatusInfo(formatted, Colors.grey.shade500);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo(this.label, this.color);
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
  String userName = 'Guest';
  String customerId = '';
  String phoneNumber = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final tenantIdFromPrefs =
          prefs.getString('tenantId') ?? prefs.getString('databaseName');

      setState(() {
        userEmail = email;
      });

      // Sync branding even if user data is still loading or if email is null
      if (tenantIdFromPrefs != null) {
        await FirestoreService.instance.syncBranding(tenantIdFromPrefs);
      }

      if (email != null) {
        final query = await FirestoreService.instance
            .collection('AMC_user', tenantId: tenantIdFromPrefs)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final userData = query.docs.first.data();
          setState(() {
            userName = userData['name'] ?? 'Guest';
            customerId = userData['Id'] ?? '';
            phoneNumber =
                (userData['Phone Number'] ?? userData['phonenumber'])
                    ?.toString() ??
                '';
          });
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async {
            SystemNavigator.pop();
            return true;
          },
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.exit_to_app, color: Theme.of(context).primaryColor),
                const SizedBox(width: 10),
                Text(
                  "Exit App",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Are you sure you want to exit the app?",
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Exit",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
    return false;
  }

  Future<void> handleLogout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(
              "Logout",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(fontSize: 16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              )
            : _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        ThemeService.instance.appName,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      iconTheme: IconThemeData(
        color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
      ),
      elevation: 0,
      toolbarHeight: 80,
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.logout,
              color:
                  Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
              size: 22,
            ),
            onPressed: () => handleLogout(context),
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Manage your maintenance services efficiently',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Main Action Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Add Device',
                    subtitle: 'Create new maintenance requests',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDeviceType(
                            name: userName,
                            loggedInName: userName,
                            phoneNumber: phoneNumber,
                            customerId: customerId,
                          ),
                        ),
                      );
                    },
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.track_changes,
                    title: 'Track Service',
                    subtitle: 'View and manage your requests',
                    onTap: userName != 'Guest'
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AMCTrackMyService(
                                  customerName: userName,
                                  customerId: customerId,
                                ),
                              ),
                            );
                          }
                        : null,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Additional Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.notifications_active,
                    title: 'Real-time Updates',
                    subtitle: 'Get instant notifications',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.support_agent,
                    title: 'Quick Support',
                    subtitle: '24/7 assistance',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: color.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).primaryColor.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
