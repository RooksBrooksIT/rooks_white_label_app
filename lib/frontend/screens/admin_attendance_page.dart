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
  final Map<String, String> _attendanceMap = {}; // username -> status
  final Map<String, String> _remarksMap = {}; // username -> remarks
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final engineers = await AttendanceBackend.getEngineers();
      setState(() {
        _engineers = engineers;
        _attendanceMap.clear();
        _remarksMap.clear();
        for (var eng in engineers) {
          _attendanceMap[eng['username']] = 'Present'; // Default
        }
      });
      _listenToAttendance();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading engineers: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToAttendance() {
    AttendanceBackend.getAttendanceForDate(_selectedDate).listen((snapshot) {
      if (!mounted) return;
      setState(() {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final username = data['engineerUsername'];
          if (_attendanceMap.containsKey(username)) {
            _attendanceMap[username] = data['status'];
            _remarksMap[username] = data['remarks'] ?? '';
          }
        }
      });
    });
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
      _loadData(); // Re-load and re-listen
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final markedBy = 'Admin'; // In a real app, get from auth
      for (var entry in _attendanceMap.entries) {
        await AttendanceBackend.markAttendance(
          engineerUsername: entry.key,
          date: _selectedDate,
          status: entry.value,
          markedBy: markedBy,
          remarks: _remarksMap[entry.key] ?? '',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engineer Attendance'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAttendanceReportsPage(),
                ),
              );
            },
            tooltip: 'Attendance Reports',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _engineers.length,
                    itemBuilder: (context, index) {
                      final engineer = _engineers[index];
                      return _buildEngineerCard(engineer);
                    },
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Change Date'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerCard(Map<String, dynamic> engineer) {
    final username = engineer['username'];
    final currentStatus = _attendanceMap[username] ?? 'Present';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Text(
                    username.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    username.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Attendance Status:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusButton(
                  'Present',
                  Colors.green,
                  currentStatus == 'Present',
                  username,
                ),
                _buildStatusButton(
                  'Absent',
                  Colors.red,
                  currentStatus == 'Absent',
                  username,
                ),
                _buildStatusButton(
                  'Leave',
                  Colors.orange,
                  currentStatus == 'Leave',
                  username,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Add remarks (optional)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller:
                  TextEditingController(text: _remarksMap[username] ?? '')
                    ..selection = TextSelection.fromPosition(
                      TextPosition(
                        offset: (_remarksMap[username] ?? '').length,
                      ),
                    ),
              onChanged: (val) => _remarksMap[username] = val,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String status,
    Color color,
    bool isSelected,
    String username,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[username] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check, size: 16, color: Colors.white),
            if (isSelected) const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saveAttendance,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'SUBMIT ATTENDANCE',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
