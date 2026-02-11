import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _engineers = [];
  Map<String, String> _attendanceStatus = {};
  Map<String, String> _absentReasons = {};
  String _searchQuery = '';
  bool _isLoading = true;
  final String _selectedShift = 'General';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final engineers = await AttendanceBackend.getEngineers();
      final attendanceRecords = await AttendanceBackend.getDailyAttendance(
        _selectedDate,
      );

      final statusMap = <String, String>{};
      for (var record in attendanceRecords) {
        final uid = record['engineerId'];
        final status = record['status'];
        if (uid != null && status != null) {
          statusMap[uid] = status;
          if (status == 'Absent') {
            _absentReasons[uid] = record['comment'] ?? '';
          }
        }
      }

      setState(() {
        _engineers = engineers;
        _attendanceStatus = statusMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _markAsPresent() {
    int changeCount = 0;
    setState(() {
      for (var engineer in _engineers) {
        final uid = engineer['uid'];
        final currentStatus = _attendanceStatus[uid];
        if (currentStatus == null || currentStatus == 'Present') {
          if (currentStatus == null) changeCount++;
          _attendanceStatus[uid] = 'Present';
        }
      }
    });

    if (changeCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Marked $changeCount engineers as Present. Click Save to commit.",
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("All engineers already marked."),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _updateStatus(
    String uid,
    String newStatus, {
    String? reason,
  }) async {
    final previousStatus = _attendanceStatus[uid];
    final isTogglingOff = (previousStatus == newStatus) && reason == null;
    final targetStatus = isTogglingOff ? 'Present' : newStatus;

    setState(() {
      _attendanceStatus[uid] = targetStatus;
      if (reason != null && targetStatus == 'Absent') {
        _absentReasons[uid] = reason;
      }
    });

    String comment = '';
    if (targetStatus == 'Absent') {
      comment = reason ?? _absentReasons[uid] ?? 'Marked by Admin';
    } else if (targetStatus == 'OT') {
      comment = 'Overtime';
    } else if (targetStatus == 'HalfDay') {
      comment = 'Half Day';
    }

    try {
      await AttendanceBackend.saveShiftAttendance(
        engineerId: uid,
        date: _selectedDate,
        shift: _selectedShift,
        status: targetStatus,
        assignedBy: 'Admin',
        comment: comment,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          if (previousStatus == null) {
            _attendanceStatus.remove(uid);
          } else {
            _attendanceStatus[uid] = previousStatus;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> records = [];

      for (var engineer in _engineers) {
        final uid = engineer['uid'];
        final status = _attendanceStatus[uid] ?? 'Present';
        final comment = (status == 'Absent')
            ? (_absentReasons[uid] ?? '')
            : null;

        records.add({
          'engineerId': uid,
          'status': status,
          if (comment != null) 'comment': comment,
        });
      }

      await AttendanceBackend.batchSaveAttendance(
        records: records,
        date: _selectedDate,
        shift: _selectedShift,
        assignedBy: 'Admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("Attendance saved successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text("Error saving: $e"),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Attendance',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAttendanceReportsPage(),
                ),
              );
            },
            tooltip: 'Reports',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading attendance data...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildEngineerList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAttendance,
        label: const Text(
          "Save Attendance",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        icon: const Icon(Icons.save_alt_rounded),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Date Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _selectDate(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_calendar_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Change Date",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by engineer name...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Bulk Action Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade500, Colors.green.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _markAsPresent,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Mark All Present",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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

  List<Map<String, dynamic>> get _filteredEngineers {
    if (_searchQuery.isEmpty) return _engineers;
    return _engineers.where((e) {
      final name = (e['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildEngineerList() {
    final engineers = _filteredEngineers;

    if (engineers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.group_off_rounded
                  : Icons.search_off_rounded,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? "No engineers found"
                  : "No matching engineers",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isEmpty
                  ? "Add engineers to get started"
                  : "Try a different search term",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: engineers.length,
      separatorBuilder: (ctx, i) =>
          const Divider(height: 0, color: Colors.grey),
      itemBuilder: (context, index) {
        final engineer = engineers[index];
        return _buildEngineerRow(engineer, index);
      },
    );
  }

  Widget _buildEngineerRow(Map<String, dynamic> engineer, int index) {
    final uid = engineer['uid'];
    final name = engineer['username'] ?? 'Unknown';
    final currentStatus = _attendanceStatus[uid];

    bool isSelected(String status) => currentStatus == status;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engineer Name and Index
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (index + 1).toString(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              // Current Status Badge
              if (currentStatus != null && currentStatus != 'Present')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(currentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(currentStatus),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    currentStatus,
                    style: TextStyle(
                      color: _getStatusColor(currentStatus),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                uid,
                'Absent',
                Colors.red,
                isSelected('Absent'),
                Icons.person_off_rounded,
              ),
              _buildStatusChip(
                uid,
                'OT',
                Colors.blue,
                isSelected('OT'),
                Icons.timer_outlined,
              ),
              _buildStatusChip(
                uid,
                'Half Day',
                Colors.orange,
                isSelected('Half Day'),
                Icons.schedule_outlined,
              ),
              if (currentStatus == 'Present')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Present",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Absent Reason Input
          if (currentStatus == 'Absent')
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason for Absence',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      initialValue: _absentReasons[uid],
                      decoration: InputDecoration(
                        hintText: 'Enter reason...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.red.shade400,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (val) {
                        _absentReasons[uid] = val;
                      },
                      onFieldSubmitted: (val) {
                        _updateStatus(uid, 'Absent', reason: val);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String uid,
    String statusLabel,
    Color color,
    bool selected,
    IconData icon,
  ) {
    final statusValue = statusLabel == 'Half Day' ? 'HalfDay' : statusLabel;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
        color: selected ? color.withOpacity(0.08) : Colors.white,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _updateStatus(uid, statusValue),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? color : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: selected ? color : Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Absent':
        return Colors.red;
      case 'OT':
        return Colors.blue;
      case 'HalfDay':
        return Colors.orange;
      case 'Present':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
