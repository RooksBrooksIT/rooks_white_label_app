import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EngineerUpdates extends StatefulWidget {
  const EngineerUpdates({super.key});

  @override
  State<EngineerUpdates> createState() => _EngineerUpdatesState();
}

class _EngineerUpdatesState extends State<EngineerUpdates> {
  // Filter state with proper typing
  Map<String, dynamic> activeFilters = {};
  List<QueryDocumentSnapshot> filteredDocs = [];
  bool filtersApplied = false;

  // Data for filters
  List<String> engineerUsernames = ['All Engineers'];
  List<String> statusOptions = [
    'All Statuses',
    'Pending',
    'In Progress',
    'Completed',
    'Unrepairable',
  ];
  bool isLoadingEngineers = true;
  String selectedEngineer = 'All Engineers';
  String selectedStatus = 'All Statuses';
  TextEditingController bookingIdController = TextEditingController();
  TextEditingController customerIdController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _fetchEngineerUsernames();
  }

  Future<void> _fetchEngineerUsernames() async {
    try {
      QuerySnapshot querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .get();

      List<String> usernames = ['All Engineers'];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['Username'] != null) {
          usernames.add(data['Username'].toString());
        }
      }

      setState(() {
        engineerUsernames = usernames;
        isLoadingEngineers = false;
      });
    } catch (e) {
      print('Error fetching engineer usernames: $e');
      setState(() {
        isLoadingEngineers = false;
      });
    }
  }

  // Helper method for safe string conversion
  String _safeString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  void _applyFilters(List<QueryDocumentSnapshot> docs) {
    setState(() {
      filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Booking ID filter
        if (activeFilters.containsKey('bookingId')) {
          final bookingId = _safeString(data['bookingId']).toLowerCase();
          final searchTerm = activeFilters['bookingId']
              .toString()
              .toLowerCase();
          if (!bookingId.contains(searchTerm)) {
            return false;
          }
        }

        // Customer ID filter
        if (activeFilters.containsKey('customerId')) {
          final customerId = _safeString(data['id']).toLowerCase();
          final searchTerm = activeFilters['customerId']
              .toString()
              .toLowerCase();
          if (!customerId.contains(searchTerm)) {
            return false;
          }
        }

        // Date Range filter
        if (startDate != null) {
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final filterEndDate = endDate ?? startDate!;

            // Set time to start and end of day for accurate comparison
            final startOfDay = DateTime(
              startDate!.year,
              startDate!.month,
              startDate!.day,
            );
            final endOfDay = DateTime(
              filterEndDate.year,
              filterEndDate.month,
              filterEndDate.day,
              23,
              59,
              59,
            );

            if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) {
              return false;
            }
          } else {
            return false;
          }
        }

        // Engineer filter
        if (selectedEngineer != 'All Engineers') {
          final assignedEmployee = _safeString(data['assignedEmployee']);
          if (assignedEmployee != selectedEngineer) {
            return false;
          }
        }

        // Status filter - Simplified logic using statusOptions
        if (selectedStatus != 'All Statuses') {
          final engineerStatus = _safeString(
            data['engineerStatus'],
          ).toLowerCase();
          final adminStatus = _safeString(data['adminStatus']).toLowerCase();

          // Simple status matching based on selectedStatus from statusOptions
          bool statusMatches = false;

          switch (selectedStatus) {
            case 'Pending':
              statusMatches =
                  (engineerStatus == 'pending' ||
                      engineerStatus == 'assigned') &&
                  adminStatus != 'completed';
              break;
            case 'In Progress':
              statusMatches =
                  engineerStatus.contains('progress') ||
                  engineerStatus == 'in progress' ||
                  (engineerStatus == 'open' && adminStatus == 'assigned');
              break;
            case 'Completed':
              statusMatches =
                  adminStatus == 'completed' || engineerStatus == 'completed';
              break;
            case 'Unrepairable':
              statusMatches =
                  engineerStatus == 'unrepairable' ||
                  adminStatus == 'unrepairable';
              break;
            default:
              statusMatches =
                  engineerStatus == selectedStatus.toLowerCase() ||
                  adminStatus == selectedStatus.toLowerCase();
          }

          if (!statusMatches) {
            return false;
          }
        }

        return true;
      }).toList();

      // Update active filters state
      Map<String, dynamic> newFilters = {};
      if (bookingIdController.text.isNotEmpty) {
        newFilters['bookingId'] = bookingIdController.text;
      }
      if (customerIdController.text.isNotEmpty) {
        newFilters['customerId'] = customerIdController.text;
      }
      if (selectedEngineer != 'All Engineers') {
        newFilters['engineer'] = selectedEngineer;
      }
      if (selectedStatus != 'All Statuses') {
        newFilters['status'] = selectedStatus;
      }
      if (startDate != null) {
        newFilters['dateRange'] = {'start': startDate, 'end': endDate};
      }
      activeFilters = newFilters;
      filtersApplied = activeFilters.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      activeFilters.clear();
      filteredDocs.clear();
      filtersApplied = false;
      bookingIdController.clear();
      customerIdController.clear();
      selectedEngineer = 'All Engineers';
      selectedStatus = 'All Statuses';
      startDate = null;
      endDate = null;
    });
  }

  void _removeFilter(String key) {
    setState(() {
      activeFilters.remove(key);
      if (key == 'bookingId') {
        bookingIdController.clear();
      } else if (key == 'customerId') {
        customerIdController.clear();
      } else if (key == 'engineer') {
        selectedEngineer = 'All Engineers';
      } else if (key == 'status') {
        selectedStatus = 'All Statuses';
      } else if (key == 'dateRange') {
        startDate = null;
        endDate = null;
      }
      if (activeFilters.isEmpty) {
        filtersApplied = false;
        filteredDocs.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineer Updates',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt_rounded, size: 24),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _buildFilterDialog(),
                  );
                },
              ),
              if (activeFilters.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      activeFilters.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Enhanced Filter summary
            _buildEnhancedFilterSummary(),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.instance
                    .collection('Admin_details')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  final updateDocs = snapshot.data?.docs ?? [];
                  final docsToShow = filtersApplied ? filteredDocs : updateDocs;
                  final reversedDocs = docsToShow.reversed.toList();

                  if (reversedDocs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reversedDocs.length,
                    itemBuilder: (context, index) {
                      return EngineerUpdateCard(reversedDocs[index], index + 1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFilterSummary() {
    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active Filters (${activeFilters.length}):',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearAllFilters,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeFilters.entries.map((entry) {
              return _buildEnhancedFilterChip(entry.key, entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterChip(String key, dynamic value) {
    String label = '';
    IconData icon = Icons.filter_alt;

    switch (key) {
      case 'engineer':
        label = 'Engineer: $value';
        icon = Icons.engineering;
        break;
      case 'status':
        label = 'Status: $value';
        icon = Icons.start;
        break;
      case 'bookingId':
        label = 'Booking ID: $value';
        icon = Icons.confirmation_number;
        break;
      case 'customerId':
        label = 'Customer ID: $value';
        icon = Icons.person;
        break;
      case 'dateRange':
        if (startDate != null) {
          final end = endDate ?? startDate;
          label =
              'Date: ${startDate!.day}/${startDate!.month}/${startDate!.year}';
          if (endDate != null && endDate != startDate) {
            label += ' to ${end!.day}/${end.month}/${end.year}';
          }
          icon = Icons.calendar_today;
          break;
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (key == 'engineer') {
                setState(() {
                  selectedEngineer = 'All Engineers';
                  _removeFilter(key);
                });
              } else if (key == 'status') {
                setState(() {
                  selectedStatus = 'All Statuses';
                  _removeFilter(key);
                });
              }
            },
            child: Icon(
              Icons.close,
              size: 14,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDialog() {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                if (activeFilters.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Booking ID Filter
            const Text(
              'Booking ID',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: bookingIdController,
                decoration: InputDecoration(
                  hintText: 'Enter booking ID',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.confirmation_number,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      activeFilters.remove('bookingId');
                    } else {
                      activeFilters['bookingId'] = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Customer ID Filter
            const Text(
              'Customer ID',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: customerIdController,
                decoration: InputDecoration(
                  hintText: 'Enter customer ID',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      activeFilters.remove('customerId');
                    } else {
                      activeFilters['customerId'] = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Engineer Filter
            const Text(
              'Engineer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: selectedEngineer,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: engineerUsernames.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEngineer = value!;
                    if (value == 'All Engineers') {
                      activeFilters.remove('engineer');
                    } else {
                      activeFilters['engineer'] = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Date Range Filter
            const Text(
              'Date Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          startDate = date;
                          if (startDate != null) {
                            activeFilters['dateRange'] = {
                              'start': startDate,
                              'end': endDate,
                            };
                          } else {
                            activeFilters.remove('dateRange');
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            startDate != null
                                ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                                : 'Start Date',
                            style: TextStyle(
                              color: startDate != null
                                  ? Colors.black
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          endDate = date;
                          if (startDate != null) {
                            activeFilters['dateRange'] = {
                              'start': startDate,
                              'end': endDate,
                            };
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            endDate != null
                                ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                                : 'End Date',
                            style: TextStyle(
                              color: endDate != null
                                  ? Colors.black
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status Filter
            const Text(
              'Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: statusOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value!;
                    if (value == 'All Statuses') {
                      activeFilters.remove('status');
                    } else {
                      activeFilters['status'] = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearAllFilters();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      FirestoreService.instance
                          .collection('Admin_details')
                          .get()
                          .then((snapshot) {
                            _applyFilters(snapshot.docs);
                          });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading updates...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            filtersApplied
                ? "No matching updates found"
                : "No Engineer Updates",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtersApplied
                ? "Try adjusting your filters"
                : "Updates will appear here",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          if (filtersApplied)
            TextButton(
              onPressed: _clearAllFilters,
              child: Text(
                'Clear Filters',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EngineerUpdateCard extends StatefulWidget {
  final QueryDocumentSnapshot updateData;
  final int serialNumber;
  const EngineerUpdateCard(this.updateData, this.serialNumber, {super.key});

  @override
  _EngineerUpdateCardState createState() => _EngineerUpdateCardState();
}

class _EngineerUpdateCardState extends State<EngineerUpdateCard> {
  bool isExpanded = false;
  late TextEditingController statusDescController;
  late TextEditingController amountController;
  String selectedStatus = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.updateData.data() as Map<String, dynamic>;

    statusDescController = TextEditingController(
      text: data['statusDescription'] ?? '',
    );
    amountController = TextEditingController(
      text: data['amount']?.toString() ?? '0',
    );

    // SIMPLIFIED STATUS INITIALIZATION
    // Prefer engineerStatus, fallback to adminStatus, then default to 'Pending'
    String engineerStatus = data['engineerStatus']?.toString() ?? '';
    String adminStatus = data['adminStatus']?.toString() ?? '';

    if (engineerStatus.isNotEmpty) {
      selectedStatus = engineerStatus;
    } else if (adminStatus.isNotEmpty) {
      selectedStatus = adminStatus;
    } else {
      selectedStatus = 'Pending';
    }

    // Ensure the selected status is one of the valid options
    if (![
      'Pending',
      'In Progress',
      'Completed',
      'Unrepairable',
    ].contains(selectedStatus)) {
      selectedStatus = 'Pending';
    }
  }

  @override
  void dispose() {
    statusDescController.dispose();
    amountController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> updateFirestore(String action) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      DocumentReference docRef = FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.updateData.id);

      // Get the original data to access customer details
      final originalData = widget.updateData.data() as Map<String, dynamic>;
      String customerPhoneNumber = originalData['mobileNumber'] ?? '';
      String bookingId = originalData['bookingId'] ?? '';
      String customerName = originalData['customerName'] ?? '';

      Map<String, dynamic> updateData = {
        'statusDescription': statusDescController.text,
        'amount': double.tryParse(amountController.text) ?? 0,
        // Add customer details for notification
        'mobileNumber': customerPhoneNumber,
        'bookingId': bookingId,
        'customerName': customerName,
      };

      // CORRECTED STATUS MAPPING LOGIC
      switch (action) {
        case 'Pending':
          updateData['engineerStatus'] = 'Pending';
          updateData['adminStatus'] = 'Pending';
          break;
        case 'In Progress':
          updateData['engineerStatus'] = 'In Progress';
          updateData['adminStatus'] = 'In Progress';
          break;
        case 'Completed':
          updateData['engineerStatus'] = 'Completed';
          updateData['adminStatus'] = 'Completed';
          break;
        case 'Unrepairable':
          updateData['engineerStatus'] = 'Unrepairable';
          updateData['adminStatus'] = 'Unrepairable';
          break;
        default:
          // Fallback for any unexpected status
          updateData['engineerStatus'] = action;
          updateData['adminStatus'] = action;
      }

      // Update the main document
      await docRef.update(updateData);

      // Also update the Engineer_updates collection
      QuerySnapshot existingDocs = await FirestoreService.instance
          .collection('Engineer_updates')
          .where('bookingId', isEqualTo: widget.updateData['bookingId'])
          .get();

      if (existingDocs.docs.isNotEmpty) {
        await existingDocs.docs.first.reference.update({
          'status': action,
          'statusDescription': statusDescController.text,
          'amount': double.tryParse(amountController.text) ?? 0,
        });
      } else {
        final data = widget.updateData.data() as Map<String, dynamic>;
        await FirestoreService.instance.collection('Engineer_updates').add({
          'bookingId': data['bookingId'] ?? 'N/A',
          'customerName': data['customerName'] ?? 'N/A',
          'deviceBrand': data['deviceBrand'] ?? 'N/A',
          'deviceCondition': data['deviceCondition'] ?? 'N/A',
          'assignedEmployee': data['assignedEmployee'] ?? 'N/A',
          'status': action,
          'statusDescription': statusDescController.text,
          'amount': double.tryParse(amountController.text) ?? 0,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Trigger in-app notification entry for AdminUpdatesPage when ticket is closed
      if (action == 'Completed' || action == 'Unrepairable') {
        try {
          await FirestoreService.instance.collection('notifications').add({
            'customerName': customerName,
            'bookingId': bookingId,
            'title': 'Ticket Closed',
            'body': 'Your ticket $bookingId has been ${action.toLowerCase()}.',
            'timestamp': FieldValue.serverTimestamp(),
            'seen': false,
          });
        } catch (e) {
          // Log but do not block UI
          debugPrint('Failed to create notification doc: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $action'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showConfirmationDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).primaryColor,
                size: 40,
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Update',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Change status to "$action"?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        updateFirestore(action);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color getStatusColor(String status) {
    if (status.toLowerCase() == 'open') {
      return Colors.orange;
    }
    if (status.toLowerCase() == 'closed') {
      return Colors.green;
    }
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Unrepairable':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 100,
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format payment data in bill format
  Widget _buildPaymentInfo(List<dynamic>? payments, Map<String, dynamic> data) {
    if (payments == null || payments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the main amount from document data
    final mainAmount = (data['amount'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Payment Information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0B3470),
          ),
        ),
        const SizedBox(height: 12),

        // Bill-like container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bill header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B3470),
                      ),
                    ),
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B3470),
                      ),
                    ),
                  ],
                ),
              ),

              // Payment items
              ...payments.asMap().entries.map((entry) {
                final index = entry.key;
                final payment = entry.value as Map<String, dynamic>;
                final paymentMethod =
                    payment['paymentMethod']?.toString() ?? 'N/A';
                final paymentType = payment['paymentType']?.toString() ?? 'N/A';
                final amount = payment['amount']?.toString() ?? '0';
                final addedBy = payment['addedBy']?.toString() ?? 'N/A';
                final addedAt = _formatPaymentDate(payment['addedAt']);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == payments.length - 1
                            ? Colors.transparent
                            : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paymentMethod,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Type: $paymentType',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹$amount',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Added by $addedBy',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            addedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Total section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      '₹${mainAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build Total Amount Section that shows on ALL tickets
  Widget _buildTotalAmountSection(Map<String, dynamic> data) {
    // Get the main amount from document data - handle all possible cases
    final amount = data['amount'];
    double mainAmount = 0;
    bool hasAmount = false;

    if (amount != null) {
      if (amount is num) {
        mainAmount = amount.toDouble();
        hasAmount = true;
      } else if (amount is String) {
        mainAmount = double.tryParse(amount) ?? 0;
        hasAmount = mainAmount > 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasAmount
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAmount
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Amount:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: hasAmount
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
          ),
          Text(
            hasAmount ? '₹${mainAmount.toStringAsFixed(2)}' : 'No data found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: hasAmount ? 18 : 14,
              color: hasAmount
                  ? Theme.of(context).primaryColor
                  : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Build Field Images Section
  Widget _buildFieldImagesSection(Map<String, dynamic> data) {
    // Handle both 'images' and 'imageUrls' fields for backward compatibility
    final images = data['images'] as List<dynamic>? ?? [];
    final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];

    // Combine both lists and remove duplicates
    final allImages = <dynamic>{...images, ...imageUrls}.toList();

    if (allImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Field Images',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0B3470),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Images captured during field visit:',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final imageUrl = allImages[idx];
              return GestureDetector(
                onTap: () {
                  _showImageDialog(context, imageUrl);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Image ${idx + 1}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatPaymentDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      if (date is String) {
        // Parse ISO string format: "2025-10-09T11:24:58+05:30"
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
      } else if (date is Timestamp) {
        final parsedDate = date.toDate();
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.updateData.data() as Map<String, dynamic>;
    final assignedEmployee = data['assignedEmployee'] ?? 'Not Assigned';
    final customerid = data['id'] ?? 'N/A';
    final payments = data['payments'] as List<dynamic>?;

    // Determine status display for color
    String statusForColor = '';
    String engineerStatus = data['engineerStatus'] ?? '';
    String adminStatus = data['adminStatus'] ?? '';

    if (engineerStatus.toLowerCase() == 'open') {
      statusForColor = 'open';
    } else if (adminStatus.toLowerCase() == 'closed') {
      statusForColor = 'closed';
    } else {
      statusForColor = engineerStatus.isNotEmpty ? engineerStatus : 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: getStatusColor(statusForColor),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.serialNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    data['bookingId'] ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFF0B3470),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Customer: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: data['customerName'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Customer ID: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: customerid,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: Theme.of(context).primaryColor,
                          ),
                          onPressed: () =>
                              setState(() => isExpanded = !isExpanded),
                        ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Device: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: data['deviceBrand'] ?? 'N/A',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: getStatusColor(statusForColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                selectedStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Customer ID: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              TextSpan(text: customerid),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Assigned Engineer: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color.fromARGB(255, 177, 97, 5),
                                ),
                              ),
                              TextSpan(text: assignedEmployee),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            children: [
                              const TextSpan(
                                text: 'Customer Assigned Date: ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: _formatTimestamp(
                                  data['timestamp'] as Timestamp?,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            children: [
                              const TextSpan(
                                text: 'Problem: ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(text: data['deviceCondition'] ?? 'N/A'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            children: [
                              const TextSpan(
                                text: 'Engineer Status (admin): ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(text: data['adminStatus'] ?? 'N/A'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            children: [
                              const TextSpan(
                                text: 'Engineer Status Description: ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(text: data['description'] ?? 'N/A'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Engineer current status: ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: data['engineerStatus'] ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Captured Location Section
                        if (data['lat'] != null && data['lng'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Logged Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Lat: ${data['lat'].toStringAsFixed(6)}, Lng: ${data['lng'].toStringAsFixed(6)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final lat = data['lat'];
                                    final lng = data['lng'];
                                    final url =
                                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(
                                        Uri.parse(url),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text(
                                    'View',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Only show payment info OR total amount, not both
                        if (payments != null && payments.isNotEmpty)
                          _buildPaymentInfo(payments, data)
                        else
                          _buildTotalAmountSection(data),

                        // FIELD IMAGES SECTION
                        _buildFieldImagesSection(data),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        const Text(
                          'Update Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF0B3470),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status description and amount fields
                        TextField(
                          controller: statusDescController,
                          decoration: InputDecoration(
                            labelText: 'Status Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                          maxLines: 2,
                        ),
                        // const SizedBox(height: 16),
                        // TextField(
                        //   controller: amountController,
                        //   keyboardType: TextInputType.numberWithOptions(
                        //     decimal: true,
                        //   ),
                        //   inputFormatters: [
                        //     FilteringTextInputFormatter.allow(
                        //       RegExp(r'^\d*\.?\d{0,2}'),
                        //     ),
                        //   ],
                        //   decoration: InputDecoration(
                        //     labelText: 'Amount',
                        //     border: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(8),
                        //     ),
                        //     contentPadding: const EdgeInsets.symmetric(
                        //       vertical: 12,
                        //       horizontal: 16,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            SizedBox(
                              height: 60,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedStatus,
                                  isExpanded: true,
                                  items:
                                      [
                                            'Pending',
                                            'In Progress',
                                            'Completed',
                                            'Unrepairable',
                                          ]
                                          .map(
                                            (status) => DropdownMenuItem(
                                              value: status,
                                              child: Text(status),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedStatus = value!;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 19,
                                      vertical: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _showConfirmationDialog(
                                        selectedStatus,
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Update Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
