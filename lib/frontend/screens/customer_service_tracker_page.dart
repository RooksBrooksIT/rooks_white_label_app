// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:lottie/lottie.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'dart:async';

// import 'package:subscription_rooks_app/backend/screens/customer_service_tracker_page.dart';

// class AdminUpdatesPage extends StatefulWidget {
//   final String name;
//   final String mobileNumber;

//   const AdminUpdatesPage({
//     super.key,
//     required this.name,
//     required this.mobileNumber,
//   });

//   @override
//   State<AdminUpdatesPage> createState() => _AdminUpdatesPageState();
// }

// class _AdminUpdatesPageState extends State<AdminUpdatesPage> {
//   // Static colors removed in favor of dynamic theme values

//   bool showBanner = false;
//   String bannerMessage = '';

//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//   late StreamSubscription<QuerySnapshot> _notificationsSub;

//   @override
//   void initState() {
//     super.initState();

//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

//     const AndroidInitializationSettings androidInitSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const DarwinInitializationSettings iosInitSettings =
//         DarwinInitializationSettings(
//           requestAlertPermission: true,
//           requestBadgePermission: true,
//           requestSoundPermission: true,
//         );

//     const InitializationSettings initSettings = InitializationSettings(
//       android: androidInitSettings,
//       iOS: iosInitSettings,
//     );

//     flutterLocalNotificationsPlugin.initialize(initSettings);

//     _notificationsSub =
//         CustomerServiceTrackerBackend.getNotificationsStream(
//           widget.name,
//         ).listen((snapshot) {
//           for (var change in snapshot.docChanges) {
//             if (change.type == DocumentChangeType.added) {
//               final data = change.doc.data() as Map<String, dynamic>?;
//               if (data != null && (data['seen'] != true)) {
//                 _showLocalNotification(
//                   data['title'] as String?,
//                   data['body'] as String?,
//                 );
//                 setState(() {
//                   showBanner = true;
//                   bannerMessage =
//                       data['body'] as String? ??
//                       'A ticket status has been updated.';
//                 });
//                 CustomerServiceTrackerBackend.markNotificationAsSeen(
//                   change.doc.id,
//                 );
//               }
//             }
//           }
//         });

//     FirebaseMessaging.instance.requestPermission().then((settings) {
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         print('Notification permission granted');
//       } else {
//         print('Notification permission declined');
//       }
//     });

//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       if (message.notification != null) {
//         _showLocalNotification(
//           message.notification!.title,
//           message.notification!.body,
//         );

//         setState(() {
//           showBanner = true;
//           bannerMessage =
//               message.notification!.body ?? 'A ticket status has been updated.';
//         });
//       }
//     });

//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       // Optional: Add navigation or refresh logic here when the app opens from notification
//     });
//   }

//   Future<void> _showLocalNotification(String? title, String? body) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//           'channel_id',
//           'channel_name',
//           channelDescription: 'Channel for ticket updates',
//           importance: Importance.max,
//           priority: Priority.high,
//           ticker: 'ticker',
//         );

//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
//     const NotificationDetails platformDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     await flutterLocalNotificationsPlugin.show(
//       0,
//       title,
//       body,
//       platformDetails,
//       payload: '',
//     );
//   }

//   @override
//   void dispose() {
//     try {
//       _notificationsSub.cancel();
//     } catch (_) {}
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).primaryColor,
//         elevation: 6,
//         centerTitle: true,
//         iconTheme: IconThemeData(
//           color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
//         ),
//         title: Text(
//           'Admin Ticket Updates',
//           style: TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.w700,
//             letterSpacing: 0.6,
//             color:
//                 Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Column(
//         children: [
//           if (showBanner)
//             MaterialBanner(
//               content: Text(
//                 bannerMessage,
//                 style: const TextStyle(fontSize: 16, color: Colors.white),
//               ),
//               backgroundColor: Colors.green.shade700,
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     setState(() {
//                       showBanner = false;
//                     });
//                   },
//                   child: const Text(
//                     'DISMISS',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ],
//             ),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: CustomerServiceTrackerBackend.getTicketsStream(
//                 widget.name,
//                 widget.mobileNumber,
//               ),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(
//                     child: Lottie.asset(
//                       'assets/loading_animation.json',
//                       width: 110,
//                       repeat: true,
//                     ),
//                   );
//                 }
//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Text(
//                       'Failed to load tickets.',
//                       style: TextStyle(
//                         fontSize: 18,
//                         color: Colors.red.shade700,
//                       ),
//                     ),
//                   );
//                 }
//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return const Center(
//                     child: Text(
//                       'No tickets found.',
//                       style: TextStyle(fontSize: 18, color: Colors.black54),
//                     ),
//                   );
//                 }
//                 final tickets = snapshot.data!.docs;
//                 return ListView.separated(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                   itemCount: tickets.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 14),
//                   itemBuilder: (context, index) {
//                     final data = tickets[index].data() as Map<String, dynamic>;
//                     final documentId = tickets[index].id;
//                     return _buildTicketCard(data, documentId);
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTicketCard(Map<String, dynamic> data, String documentId) {
//     final cardColor = Theme.of(context).cardColor;
//     final canceledCardColor = Theme.of(context).disabledColor.withOpacity(0.1);
//     final bookingId = data['bookingId'] ?? 'N/A';
//     final customerName = data['customerName'] ?? 'N/A';
//     final customerId = data['id'] ?? 'Not Assigned Yet';
//     final message = data['message'] ?? '-';
//     final mobileNumber = data['mobileNumber'] ?? '-';
//     final jobType = data['JobType'] ?? '-';
//     final categoryName = data['categoryName'] ?? '-';
//     final deviceCondition = data['deviceCondition'] ?? '-';
//     final deviceBrand = data['deviceBrand'] ?? '-';
//     final description = data['description'] ?? '-';
//     final amount = data['amount']?.toString() ?? '0';
//     final Timestamp? timestamp = data['timestamp'];
//     final feedback = data['feedback'] ?? '';
//     final rawStatus = data['adminStatus'] ?? '';
//     final adminStatus = data['adminStatus'] ?? '';
//     final customerDecision = data['Customer_decision'] ?? '';
//     final statusInfo = _mapEngineerStatus(rawStatus);
//     final isCompleted = rawStatus.toLowerCase() == 'completed';
//     final hasFeedback = feedback.isNotEmpty;
//     final isCanceled = adminStatus == 'Canceled' || customerDecision.isNotEmpty;

//     return GestureDetector(
//       onTap: () {
//         if (isCompleted && !hasFeedback && !isCanceled) {
//           _showFeedbackDialog(context, documentId);
//         }
//       },
//       child: Card(
//         color: isCanceled ? canceledCardColor : cardColor,
//         elevation: isCanceled ? 1 : 3,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//         shadowColor: isCanceled ? Colors.grey : Colors.grey.shade200,
//         child: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(
//                     Icons.receipt,
//                     color: isCanceled
//                         ? Colors.grey.shade700
//                         : Theme.of(context).primaryColor,
//                     size: 26,
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(
//                       "Booking ID: $bookingId",
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.w700,
//                         color: isCanceled
//                             ? Theme.of(context).disabledColor
//                             : Theme.of(context).textTheme.bodyLarge?.color,
//                         letterSpacing: 0.4,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   if (isCanceled)
//                     _buildStatusChip('Canceled', Colors.red.shade600)
//                   else
//                     _buildStatusChip(statusInfo.label, statusInfo.color),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 children: [
//                   Icon(
//                     Icons.engineering_outlined,
//                     color: isCanceled
//                         ? Colors.grey.shade700
//                         : const Color.fromARGB(255, 255, 11, 11),
//                     size: 26,
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(
//                       "Your ID: $customerId",
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.w700,
//                         color: isCanceled
//                             ? Theme.of(context).disabledColor
//                             : Theme.of(context).textTheme.bodyLarge?.color,
//                         letterSpacing: 0.4,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),

//               _buildDetailRow(
//                 Icons.person_outline,
//                 'Customer',
//                 customerName,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.message_outlined,
//                 'Message',
//                 message,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.phone_android_rounded,
//                 'Mobile ',
//                 mobileNumber,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.work_outlined,
//                 'Job Type',
//                 jobType,
//                 isCanceled,
//               ),

//               _buildDetailRow(
//                 Icons.devices_other_outlined,
//                 'Device Condition',
//                 deviceCondition,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.branding_watermark_outlined,
//                 'Device Brand',
//                 deviceBrand,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.description_outlined,
//                 'Description',
//                 description,
//                 isCanceled,
//               ),
//               _buildDetailRow(
//                 Icons.calendar_today_outlined,
//                 'Created On',
//                 _formatTimestamp(timestamp),
//                 isCanceled,
//               ),

//               // Show cancellation reason if canceled by customer
//               if (isCanceled && customerDecision.isNotEmpty)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.red.shade200, width: 1.5),
//                   ),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Icon(
//                         Icons.cancel_outlined,
//                         color: Colors.red.shade700,
//                         size: 22,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Cancellation Note:',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.red.shade800,
//                                 fontSize: 15,
//                               ),
//                             ),
//                             const SizedBox(height: 5),
//                             Text(
//                               "$customerDecision by you",
//                               style: TextStyle(
//                                 color: Colors.red.shade700,
//                                 fontSize: 14,
//                                 height: 1.3,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               if (hasFeedback)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: isCanceled
//                         ? Colors.grey.shade300
//                         : Colors.green.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(
//                       color: isCanceled ? Colors.grey : Colors.green.shade200,
//                       width: 1.5,
//                     ),
//                   ),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Icon(
//                         Icons.feedback_outlined,
//                         color: isCanceled
//                             ? Colors.grey.shade700
//                             : Colors.green.shade700,
//                         size: 22,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Your Feedback:',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: isCanceled
//                                     ? Colors.grey.shade800
//                                     : Colors.green.shade800,
//                                 fontSize: 15,
//                               ),
//                             ),
//                             const SizedBox(height: 5),
//                             Text(
//                               feedback,
//                               style: TextStyle(
//                                 color: isCanceled
//                                     ? Colors.grey.shade700
//                                     : Colors.green.shade700,
//                                 fontSize: 14,
//                                 height: 1.3,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               if (isCompleted && !hasFeedback && !isCanceled)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.blue.shade200, width: 1.5),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.touch_app_rounded,
//                         color: Colors.blue.shade700,
//                         size: 22,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           'Tap anywhere on this card to provide your feedback',
//                           style: TextStyle(
//                             color: Colors.blue.shade700,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               if (!isCompleted && !isCanceled)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(
//                       color: Colors.orange.shade200,
//                       width: 1.5,
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.info_outline_rounded,
//                         color: Colors.orange.shade700,
//                         size: 22,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           'Feedback will be available once the status is "Completed"',
//                           style: TextStyle(
//                             color: Colors.orange.shade700,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               // Cancel Ticket Button (only show if not already canceled)
//               if (!isCanceled)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   child: ElevatedButton(
//                     onPressed: () =>
//                         _showCancelConfirmationDialog(context, documentId),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red.shade600,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 12,
//                         horizontal: 24,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       elevation: 3,
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.cancel_outlined, size: 20),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Cancel Ticket',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//               // Canceled message (only show if canceled)
//               if (isCanceled)
//                 Container(
//                   margin: const EdgeInsets.symmetric(vertical: 10),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.red.shade200, width: 1.5),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.cancel_outlined,
//                         color: Colors.red.shade700,
//                         size: 22,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           'This ticket has been canceled',
//                           style: TextStyle(
//                             color: Colors.red.shade700,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//               const SizedBox(height: 20),
//               Text(
//                 'Bill Amount :',
//                 style: TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 18,
//                   color: isCanceled
//                       ? Theme.of(context).disabledColor
//                       : Theme.of(context).textTheme.bodyLarge?.color,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 '₹$amount',
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontFamily: 'times new roman',
//                   fontWeight: FontWeight.bold,
//                   color: isCanceled
//                       ? Colors.grey.shade700
//                       : const Color.fromARGB(255, 13, 116, 18),
//                   letterSpacing: 1,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailRow(
//     IconData icon,
//     String title,
//     String content,
//     bool isCanceled,
//   ) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(
//             icon,
//             color: isCanceled
//                 ? Colors.grey.shade600
//                 : Theme.of(context).primaryColor.withOpacity(0.85),
//             size: 20,
//           ),
//           const SizedBox(width: 14),
//           SizedBox(
//             width: 110,
//             child: Text(
//               '$title:',
//               style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 color: isCanceled
//                     ? Theme.of(context).disabledColor
//                     : Theme.of(context).textTheme.bodyLarge?.color,
//                 fontSize: 15,
//               ),
//             ),
//           ),
//           const SizedBox(width: 6),
//           Expanded(
//             child: Text(
//               content,
//               style: TextStyle(
//                 color: isCanceled ? Colors.grey.shade700 : Colors.black54,
//                 fontSize: 14,
//                 height: 1.3,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusChip(String label, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//       decoration: BoxDecoration(
//         color: color,
//         borderRadius: BorderRadius.circular(22),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.45),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           color: Colors.white,
//           fontWeight: FontWeight.w700,
//           fontSize: 13,
//           letterSpacing: 0.4,
//         ),
//       ),
//     );
//   }

//   _StatusInfo _mapEngineerStatus(String status) {
//     final lowerStatus = status.toLowerCase();
//     switch (lowerStatus) {
//       case 'complete':
//       case 'completed':
//         return _StatusInfo('Completed', Colors.green.shade600);
//       case 'open':
//         return _StatusInfo('Assigned', Colors.orange.shade700);
//       case 'not assigned':
//         return _StatusInfo('Not Assigned', Colors.red.shade700);
//       default:
//         return _StatusInfo(status, Colors.grey.shade500);
//     }
//   }

//   String _formatTimestamp(Timestamp? timestamp) {
//     if (timestamp == null) return 'Unknown';
//     return DateFormat('dd MMM yyyy').format(timestamp.toDate());
//   }

//   void _showFeedbackDialog(BuildContext context, String documentId) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return FeedbackDialog(documentId: documentId);
//       },
//     );
//   }

//   void _showCancelConfirmationDialog(BuildContext context, String documentId) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
//               const SizedBox(width: 10),
//               Text('Cancel Ticket?'),
//             ],
//           ),
//           content: Text(
//             'Are you sure you want to cancel this ticket? This action cannot be undone.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('No', style: TextStyle(color: Colors.grey.shade700)),
//             ),
//             ElevatedButton(
//               onPressed: () => _cancelTicket(documentId, context),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade600,
//               ),
//               child: Text('Yes, Cancel'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _cancelTicket(String documentId, BuildContext context) async {
//     try {
//       await CustomerServiceTrackerBackend.cancelTicket(documentId, "by you");

//       if (!mounted) return;
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Ticket canceled successfully!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Failed to cancel ticket. Please try again.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }

// class FeedbackDialog extends StatefulWidget {
//   final String documentId;
//   const FeedbackDialog({super.key, required this.documentId});

//   @override
//   _FeedbackDialogState createState() => _FeedbackDialogState();
// }

// class _FeedbackDialogState extends State<FeedbackDialog> {
//   String? selectedFeedback;
//   String feedbackMessage = '';

//   final Map<String, Map<String, dynamic>> feedbackOptions = {
//     'Good': {
//       'emoji': '😊',
//       'message': 'Thank you for your positive feedback!',
//       'response': 'Thank you for your concern',
//       'flag': 'Good',
//     },
//     'Ok': {
//       'emoji': '😐',
//       'message':
//           'We appreciate your feedback and will strive to do better next time.',
//       'response': 'We will do better next time',
//       'flag': 'Ok',
//     },
//     'Not Satisfied': {
//       'emoji': '😞',
//       'message':
//           'We\'re sorry to hear that. Our admin will call you shortly to address your concerns.',
//       'response': 'Our Admin will call you',
//       'flag': 'Not Satisfied',
//     },
//   };

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       elevation: 10,
//       child: Container(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'How was your experience?',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey.shade800,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: feedbackOptions.entries.map((entry) {
//                 final String option = entry.key;
//                 final String emoji = entry.value['emoji'];
//                 final bool isSelected = selectedFeedback == option;
//                 return GestureDetector(
//                   onTap: () {
//                     setState(() {
//                       selectedFeedback = option;
//                       feedbackMessage = entry.value['message'];
//                     });
//                   },
//                   child: Column(
//                     children: [
//                       Container(
//                         width: 70,
//                         height: 70,
//                         decoration: BoxDecoration(
//                           color: isSelected
//                               ? Colors.blue.shade100
//                               : Colors.grey.shade100,
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                             color: isSelected
//                                 ? Colors.blue
//                                 : Colors.grey.shade300,
//                             width: 2,
//                           ),
//                         ),
//                         child: Center(
//                           child: Text(
//                             emoji,
//                             style: const TextStyle(fontSize: 30),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         option,
//                         style: TextStyle(
//                           fontWeight: isSelected
//                               ? FontWeight.bold
//                               : FontWeight.normal,
//                           color: isSelected
//                               ? Colors.blue
//                               : Colors.grey.shade700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//             const SizedBox(height: 20),
//             if (selectedFeedback != null)
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.info_outline, color: Colors.blue.shade700),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         feedbackMessage,
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.blue.shade800,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: selectedFeedback != null
//                   ? () => _submitFeedback(context)
//                   : null,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 30,
//                   vertical: 12,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//               ),
//               child: const Text(
//                 'Submit Feedback',
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _submitFeedback(BuildContext context) async {
//     try {
//       await CustomerServiceTrackerBackend.submitFeedback(
//         widget.documentId,
//         feedbackOptions[selectedFeedback]!['flag'],
//       );

//       if (!mounted) return;
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Feedback submitted successfully!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Failed to submit feedback. Please try again.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }

// class _StatusInfo {
//   final String label;
//   final Color color;
//   _StatusInfo(this.label, this.color);
// }
