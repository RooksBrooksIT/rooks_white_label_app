import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminEngineerReports extends StatefulWidget {
  const AdminEngineerReports({super.key});

  @override
  _AdminEngineerReportsState createState() => _AdminEngineerReportsState();
}

class _AdminEngineerReportsState extends State<AdminEngineerReports> {
  String? selectedEngineer;
  bool isDateFilterEnabled = false;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;
  bool isDateRangeMode = false; // false = single date, true = date range

  // This map holds counts of admin statuses per engineer dynamically
  Map<String, Map<String, int>> engineerStatusCounts = {};

  // Holds the set of all unique normalized statuses found
  Set<String> allStatuses = {};

  // Stream to fetch engineer usernames from EngineerLogin collection
  Stream<List<String>> getEngineerUsernames() {
    return FirestoreService.instance
        .collection('EngineerLogin')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    (doc.data()['Username'] as String).trim().toLowerCase(),
              )
              .toList();
        });
  }

  Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  @override
  Widget build(BuildContext context) {
    final adminDetailsStream = _buildAdminDetailsStream();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Engineer\'s Progress Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Filter section
                    _buildFilterSection(),

                    const SizedBox(height: 20),

                    // Results section
                    StreamBuilder<QuerySnapshot>(
                      stream: adminDetailsStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          );
                        }

                        engineerStatusCounts.clear();
                        allStatuses.clear();

                        final docs = snapshot.data!.docs;
                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          String? rawEngineerName = data['assignedEmployee']
                              ?.toString();
                          if (rawEngineerName != null) {
                            final engineerName = rawEngineerName
                                .trim()
                                .toLowerCase();

                            final rawStatus =
                                data['adminStatus']?.toString() ?? '';
                            final normalizedStatus = _normalizeStatusKey(
                              rawStatus,
                            );

                            allStatuses.add(normalizedStatus);

                            engineerStatusCounts.putIfAbsent(
                              engineerName,
                              () => {},
                            );

                            final engineerMap =
                                engineerStatusCounts[engineerName]!;

                            engineerMap[normalizedStatus] =
                                (engineerMap[normalizedStatus] ?? 0) + 1;
                          }
                        }

                        if (selectedEngineer != null) {
                          final selectedCounts =
                              engineerStatusCounts[selectedEngineer!
                                  .toLowerCase()];

                          if (selectedCounts == null ||
                              selectedCounts.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).cardColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "No data found for selected engineer",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }

                          // Calculate total tickets matching selected engineer and date filter
                          final totalTickets = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final assignedEmployee = data['assignedEmployee']
                                ?.toString()
                                .trim()
                                .toLowerCase();
                            final timestamp = _parseTimestamp(
                              data['timestamp'],
                            );

                            if (selectedEngineer == null) return false;

                            bool matchesEngineer =
                                assignedEmployee ==
                                selectedEngineer!.toLowerCase();
                            bool matchesDate = _matchesDateFilter(timestamp);
                            return matchesEngineer && matchesDate;
                          }).length;

                          return Column(
                            children: [
                              // Total tickets card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).cardColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Total Tickets: $totalTickets',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Status counts card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).cardColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${selectedEngineer != null && selectedEngineer!.isNotEmpty ? selectedEngineer![0].toUpperCase() + selectedEngineer!.substring(1) : 'Engineer'}'s Ticket Counts",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Divider(
                                      height: 1,
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    const SizedBox(height: 16),
                                    ..._buildDynamicStatusCountRows(
                                      selectedCounts,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedEngineer = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      side: BorderSide(
                                        color: Theme.of(context).primaryColor,
                                        width: 1.5,
                                      ),
                                      foregroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('CLEAR'),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (selectedEngineer == null ||
                                          (isDateFilterEnabled &&
                                              ((!isDateRangeMode &&
                                                      selectedDate == null) ||
                                                  (isDateRangeMode &&
                                                      (fromDate == null ||
                                                          toDate == null))))) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please select an engineer and date(s) if needed',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      final filteredTickets = docs
                                          .map(
                                            (doc) =>
                                                doc.data()
                                                    as Map<String, dynamic>,
                                          )
                                          .where((data) {
                                            final assignedEmployee =
                                                data['assignedEmployee']
                                                    ?.toString()
                                                    .trim()
                                                    .toLowerCase();
                                            final timestamp = _parseTimestamp(
                                              data['timestamp'],
                                            );
                                            if (selectedEngineer == null) {
                                              return false;
                                            }
                                            bool matchesEngineer =
                                                assignedEmployee ==
                                                selectedEngineer!.toLowerCase();
                                            bool matchesDate =
                                                _matchesDateFilter(timestamp);
                                            return matchesEngineer &&
                                                matchesDate;
                                          })
                                          .toList();

                                      // Show loading dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const AlertDialog(
                                          content: Row(
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(width: 20),
                                              Text('Generating PDF...'),
                                            ],
                                          ),
                                        ),
                                      );

                                      try {
                                        final pdf = await _generatePdf(
                                          selectedEngineer!,
                                          filteredTickets,
                                        );

                                        Navigator.of(
                                          context,
                                        ).pop(); // Remove loading dialog

                                        await Printing.layoutPdf(
                                          onLayout:
                                              (PdfPageFormat format) async =>
                                                  pdf.save(),
                                          name:
                                              'Engineer_Report_${selectedEngineer}_${DateTime.now().millisecondsSinceEpoch}',
                                        );
                                      } catch (e) {
                                        Navigator.of(
                                          context,
                                        ).pop(); // Remove loading dialog
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error generating PDF: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('GENERATE PDF'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              'Select an engineer to view their progress report',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ); // Scaffold
  }

  Widget _buildFilterSection() {
    bool isDropdownDisabled =
        isDateFilterEnabled &&
        ((!isDateRangeMode && selectedDate == null) ||
            (isDateRangeMode && (fromDate == null || toDate == null)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // Date filter toggle
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isDateFilterEnabled,
                  onChanged: (bool? newValue) {
                    setState(() {
                      isDateFilterEnabled = newValue ?? false;
                      if (!isDateFilterEnabled) {
                        selectedDate = null;
                        fromDate = null;
                        toDate = null;
                        selectedEngineer = null;
                      }
                    });
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Filter by Date',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date mode toggle (Single Date vs Date Range)
          if (isDateFilterEnabled)
            Column(
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isDateRangeMode,
                        onChanged: (bool? newValue) {
                          setState(() {
                            isDateRangeMode = newValue ?? false;
                            selectedDate = null;
                            fromDate = null;
                            toDate = null;
                            selectedEngineer = null;
                          });
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDateRangeMode ? 'Date Range' : 'Single Date',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Date picker based on mode
          if (isDateFilterEnabled)
            Column(
              children: [
                if (!isDateRangeMode)
                  _buildDatePicker('Select Date', selectedDate, (pickedDate) {
                    setState(() {
                      selectedDate = pickedDate;
                      selectedEngineer = null;
                    });
                  })
                else
                  Column(
                    children: [
                      _buildDatePicker('From Date', fromDate, (pickedDate) {
                        setState(() {
                          fromDate = pickedDate;
                          // Reset toDate if it's before fromDate
                          if (toDate != null && toDate!.isBefore(pickedDate)) {
                            toDate = null;
                          }
                          selectedEngineer = null;
                        });
                      }),
                      const SizedBox(height: 12),
                      _buildDatePicker('To Date', toDate, (pickedDate) {
                        if (fromDate != null &&
                            pickedDate.isBefore(fromDate!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'To date cannot be before from date',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          toDate = pickedDate;
                          selectedEngineer = null;
                        });
                      }, minDate: fromDate),
                      if (fromDate != null && toDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Selected range: ${fromDate!.toLocal().toString().split(' ')[0]} to ${toDate!.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
            ),

          // Engineer dropdown
          Text(
            'Select Engineer',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          StreamBuilder<List<String>>(
            stream: getEngineerUsernames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              final engineers = snapshot.data ?? [];

              // Reset selectedEngineer if no longer exists
              if (selectedEngineer != null &&
                  !engineers.contains(selectedEngineer!.toLowerCase())) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      selectedEngineer = null;
                    });
                  }
                });
              }

              final items = engineers
                  .map(
                    (eng) => DropdownMenuItem<String>(
                      value: eng,
                      child: Text(
                        eng[0].toUpperCase() +
                            (eng.length > 1 ? eng.substring(1) : ''),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    isDropdownDisabled ? 0.05 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(
                      isDropdownDisabled ? 0.2 : 0.5,
                    ),
                  ),
                ),
                child: DropdownButton<String>(
                  dropdownColor: Theme.of(context).primaryColor,
                  value: selectedEngineer?.toLowerCase(),
                  hint: Text(
                    isDropdownDisabled
                        ? 'Select date(s) first'
                        : 'Choose an engineer',
                    style: TextStyle(
                      color: isDropdownDisabled
                          ? Colors.white54
                          : Colors.white70,
                    ),
                  ),
                  items: items,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDropdownDisabled ? Colors.white54 : Colors.white,
                  ),
                  onChanged: isDropdownDisabled
                      ? null
                      : (newValue) {
                          setState(() {
                            selectedEngineer = newValue;
                          });
                        },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? currentDate,
    Function(DateTime) onDateSelected, {
    DateTime? minDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: currentDate ?? DateTime.now(),
                firstDate: minDate ?? DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Theme.of(context).primaryColor,
                        onPrimary: Colors.white,
                        surface: Theme.of(context).primaryColor,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                onDateSelected(pickedDate);
              }
            },
            child: Text(
              currentDate == null
                  ? 'Select $label'
                  : '$label: ${currentDate.toLocal().toString().split(' ')[0]}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _buildAdminDetailsStream() {
    if (isDateFilterEnabled) {
      if (!isDateRangeMode && selectedDate != null) {
        // Single date filter
        final startOfDay = Timestamp.fromDate(
          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day),
        );
        final endOfDay = Timestamp.fromDate(
          DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
          ).add(const Duration(days: 1)),
        );
        return FirestoreService.instance
            .collection('Admin_details')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThan: endOfDay)
            .snapshots();
      } else if (isDateRangeMode && fromDate != null && toDate != null) {
        // Date range filter
        final startOfDay = Timestamp.fromDate(
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day),
        );
        final endOfDay = Timestamp.fromDate(
          DateTime(
            toDate!.year,
            toDate!.month,
            toDate!.day,
          ).add(const Duration(days: 1)),
        );
        return FirestoreService.instance
            .collection('Admin_details')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThan: endOfDay)
            .snapshots();
      }
    }
    // No date filter
    return FirestoreService.instance.collection('Admin_details').snapshots();
  }

  bool _matchesDateFilter(Timestamp? timestamp) {
    if (!isDateFilterEnabled) return true;
    if (timestamp == null) return false;

    final dt = timestamp.toDate();

    if (!isDateRangeMode && selectedDate != null) {
      // Single date matching
      return dt.year == selectedDate!.year &&
          dt.month == selectedDate!.month &&
          dt.day == selectedDate!.day;
    } else if (isDateRangeMode && fromDate != null && toDate != null) {
      // Date range matching
      final date = DateTime(dt.year, dt.month, dt.day);
      final from = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final to = DateTime(toDate!.year, toDate!.month, toDate!.day);

      return (date.isAfter(from) || date.isAtSameMomentAs(from)) &&
          (date.isBefore(to) || date.isAtSameMomentAs(to));
    }

    return false;
  }

  List<Widget> _buildDynamicStatusCountRows(Map<String, int> counts) {
    Color getColor(String status) {
      final lower = status.toLowerCase();
      if (lower.contains("complete")) {
        return const Color.fromARGB(255, 34, 189, 29);
      }
      if (lower.contains("progress")) return Colors.blueAccent;
      if (lower.contains("spares") || lower.contains("spa")) {
        return Colors.orange;
      }
      if (lower.contains("approval") || lower.contains("spc")) {
        return Colors.redAccent;
      }
      if (lower.contains("hold")) return Colors.grey;
      return Colors.black;
    }

    return counts.entries.map((entry) {
      final status = entry.key;
      final count = entry.value;
      return _statusRow(status, count, getColor(status));
    }).toList();
  }

  Widget _statusRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeStatusKey(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case "complete":
      case "completed":
      case "closed":
      case "close":
        return "Completed";
      case "on progress":
        return "On Progress";
      case "pending for spares":
      case "pending for spares (pfs)":
        return "Pending For Spares (PFS)";
      case "pending for approval":
      case "pending for approval (pfa)":
        return "Pending For Approval (PFA)";
      case "under the observation":
      case "on - hold":
      case "on hold":
        return "On Hold";
      default:
        return status
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  Future<pw.Document> _generatePdf(
    String engineerName,
    List<Map<String, dynamic>> tickets,
  ) async {
    final pdf = pw.Document();

    // Helper functions
    String formatTimestamp(Timestamp? timestamp) {
      if (timestamp == null) return 'N/A';
      final dt = timestamp.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    String truncateText(String text, {int maxLength = 30}) {
      if (text.length <= maxLength) return text;
      return '${text.substring(0, maxLength)}...';
    }

    String getReportPeriod() {
      if (!isDateFilterEnabled) return 'All Time';
      if (!isDateRangeMode && selectedDate != null) {
        return selectedDate!.toLocal().toString().split(' ')[0];
      }
      if (isDateRangeMode && fromDate != null && toDate != null) {
        return '${fromDate!.toLocal().toString().split(' ')[0]} to ${toDate!.toLocal().toString().split(' ')[0]}';
      }
      return 'All Time';
    }

    // Calculate statistics
    final statusCounts = <String, int>{};
    double totalAmount = 0;
    int completedTickets = 0;

    for (final ticket in tickets) {
      final status = _normalizeStatusKey(
        ticket['adminStatus']?.toString() ?? 'Unknown',
      );
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      // Calculate total amount
      final amount = double.tryParse(ticket['amount']?.toString() ?? '0') ?? 0;
      totalAmount += amount;

      // Count completed tickets
      if (status.toLowerCase().contains('complete')) {
        completedTickets++;
      }
    }

    final completionRate = tickets.isNotEmpty
        ? (completedTickets / tickets.length * 100)
        : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ENGINEER PERFORMANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue800,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'CONFIDENTIAL',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Service Management System',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // Executive Summary
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Executive Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    children: [
                      _buildSummaryCard(
                        'Total Tickets',
                        tickets.length.toString(),
                        PdfColors.blue700,
                      ),
                      pw.SizedBox(width: 10),
                      _buildSummaryCard(
                        'Completed',
                        '$completedTickets (${completionRate.toStringAsFixed(1)}%)',
                        PdfColors.green700,
                      ),
                      pw.SizedBox(width: 10),
                      _buildSummaryCard(
                        'Total Revenue',
                        '₹${totalAmount.toStringAsFixed(2)}',
                        PdfColors.orange700,
                      ),
                      pw.SizedBox(width: 10),
                      _buildSummaryCard(
                        'Avg. per Ticket',
                        '₹${tickets.isNotEmpty ? (totalAmount / tickets.length).toStringAsFixed(2) : '0.00'}',
                        PdfColors.purple700,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Engineer Information
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Engineer Details',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Name: ',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            engineerName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Report Period: ',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            getReportPeriod(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(30),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        engineerName.substring(0, 1).toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 20,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status Distribution
            if (statusCounts.isNotEmpty)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ticket Status Distribution',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusCounts.entries.map((entry) {
                        final percentage = (entry.value / tickets.length * 100);
                        return _buildStatusChip(
                          entry.key,
                          entry.value,
                          percentage,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // Detailed Ticket Analysis
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Detailed Ticket Analysis',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    'Total: ${tickets.length} tickets',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),

            // Tickets Table
            if (tickets.isEmpty)
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(40),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('📊', style: pw.TextStyle(fontSize: 24)),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'No tickets found for the selected criteria',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              pw.Table.fromTextArray(
                border: null,
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
                  ),
                ),
                rowDecoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.0),
                  2: const pw.FlexColumnWidth(0.8),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(0.7),
                  5: const pw.FlexColumnWidth(1.0),
                  6: const pw.FlexColumnWidth(1.0),
                  7: const pw.FlexColumnWidth(0.8),
                },
                headers: [
                  'Booking ID',
                  'Device Type',
                  'Brand',
                  'Issue Description',
                  'Amount',
                  'Eng Status',
                  'Admin Status',
                  'Date',
                ],
                data: tickets.map((ticket) {
                  return [
                    ticket['bookingId']?.toString() ?? 'N/A',
                    ticket['deviceType']?.toString() ?? 'N/A',
                    ticket['deviceBrand']?.toString() ?? 'N/A',
                    truncateText(
                      ticket['message']?.toString() ?? 'No description',
                      maxLength: 35,
                    ),
                    '₹${ticket['amount']?.toString() ?? '0'}',
                    _getStatusAbbr(
                      ticket['engineerStatus']?.toString() ?? 'N/A',
                    ),
                    _getStatusAbbr(ticket['adminStatus']?.toString() ?? 'N/A'),
                    formatTimestamp(ticket['timestamp'] as Timestamp?),
                  ];
                }).toList(),
              ),

            // Performance Insights
            if (tickets.isNotEmpty)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20),
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue100),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Performance Insights',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildInsightRow(
                      '📈',
                      'Completion Rate: ${completionRate.toStringAsFixed(1)}% ($completedTickets/${tickets.length} tickets)',
                      completionRate >= 70
                          ? PdfColors.green700
                          : completionRate >= 40
                          ? PdfColors.orange700
                          : PdfColors.red700,
                    ),
                    pw.SizedBox(height: 5),
                    _buildInsightRow(
                      '💰',
                      'Total Revenue Generated: ₹${totalAmount.toStringAsFixed(2)}',
                      PdfColors.green700,
                    ),
                    pw.SizedBox(height: 5),
                    _buildInsightRow(
                      '📊',
                      'Average Ticket Value: ₹${(totalAmount / tickets.length).toStringAsFixed(2)}',
                      PdfColors.blue700,
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    final Map<PdfColor, PdfColor> lightColors = {
      PdfColors.blue700: PdfColors.blue50,
      PdfColors.green700: PdfColors.green50,
      PdfColors.orange700: PdfColors.orange50,
      PdfColors.purple700: PdfColors.purple50,
    };

    final backgroundColor = lightColors[color] ?? PdfColors.grey50;

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: backgroundColor,
          border: pw.Border.all(color: color, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 8,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildStatusChip(String status, int count, double percentage) {
    PdfColor getStatusColor(String status) {
      final lower = status.toLowerCase();
      if (lower.contains("complete")) return PdfColors.green700;
      if (lower.contains("progress")) return PdfColors.blue700;
      if (lower.contains("spares")) return PdfColors.orange700;
      if (lower.contains("approval")) return PdfColors.red700;
      if (lower.contains("hold")) return PdfColors.grey700;
      return PdfColors.grey700;
    }

    PdfColor getBackgroundColor(String status) {
      final lower = status.toLowerCase();
      if (lower.contains("complete")) return PdfColors.green50;
      if (lower.contains("progress")) return PdfColors.blue50;
      if (lower.contains("spares")) return PdfColors.orange50;
      if (lower.contains("approval")) return PdfColors.red50;
      if (lower.contains("hold")) return PdfColors.grey50;
      return PdfColors.grey50;
    }

    final color = getStatusColor(status);
    final backgroundColor = getBackgroundColor(status);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            status,
            style: pw.TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: pw.TextStyle(fontSize: 8, color: color),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInsightRow(String emoji, String text, PdfColor color) {
    return pw.Row(
      children: [
        pw.Text(emoji, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusAbbr(String status) {
    final lower = status.toLowerCase();
    if (lower.contains("complete")) return "COMP";
    if (lower.contains("progress")) return "PROG";
    if (lower.contains("spares")) return "PFS";
    if (lower.contains("approval")) return "PFA";
    if (lower.contains("hold")) return "HOLD";
    if (status.length <= 8) return status;
    return status.substring(0, 8);
  }
}
