import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/backend/attendance_backend.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_attendance_reports.dart';
import 'package:intl/intl.dart';

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _engineers = [];
  final Map<String, String> _attendanceMap = {};
  final Map<String, String> _remarksMap = {};
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  int _presentCount = 0;
  int _absentCount = 0;
  int _overtimeCount = 0;

  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
          _attendanceMap[eng['username']] = 'Present';
        }
      });
      _listenToAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading engineers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToAttendance() {
    AttendanceBackend.getAttendanceForDate(_selectedDate).listen((snapshot) {
      if (!mounted) return;

      setState(() {
        // Reset counters
        _presentCount = 0;
        _absentCount = 0;
        _overtimeCount = 0;

        // Initialize defaults
        for (var eng in _engineers) {
          _attendanceMap[eng['username']] = 'Present';
          _remarksMap[eng['username']] = '';
        }

        final dateKey = DateFormat('dd/MM/yyyy').format(_selectedDate);

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final username = data['engineerUsername'];
          if (_attendanceMap.containsKey(username) &&
              data.containsKey(dateKey)) {
            final dayData = data[dateKey] as Map<String, dynamic>;
            final status = dayData['status'];
            _attendanceMap[username] = status;
            _remarksMap[username] = dayData['remarks'] ?? '';

            // Update counters
            if (status == 'Absent') {
              _absentCount++;
            } else if (status == 'Overtime') {
              _overtimeCount++;
            } else {
              _presentCount++;
            }
          }
        }

        // Update present count for remaining engineers
        _presentCount = _engineers.length - _absentCount - _overtimeCount;
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
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);

    try {
      final markedBy = 'Admin';
      int updatedCount = 0;

      for (var entry in _attendanceMap.entries) {
        if (entry.value == 'Present') {
          await AttendanceBackend.deleteAttendance(
            engineerUsername: entry.key,
            date: _selectedDate,
          );
        } else {
          await AttendanceBackend.markAttendance(
            engineerUsername: entry.key,
            date: _selectedDate,
            status: entry.value,
            markedBy: markedBy,
            remarks: _remarksMap[entry.key] ?? '',
          );
          updatedCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance updated for $updatedCount engineers!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating attendance: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAllInTab(String tabType) {
    setState(() {
      for (var eng in _engineers) {
        final username = eng['username'];
        if (eng['username'].toLowerCase().contains(
          _searchQuery.toLowerCase(),
        )) {
          _attendanceMap[username] = tabType;
        }
      }
      _updateCounters();
    });
  }

  void _clearAllInTab(String tabType) {
    setState(() {
      for (var eng in _engineers) {
        final username = eng['username'];
        if (eng['username'].toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) &&
            _attendanceMap[username] == tabType) {
          _attendanceMap[username] = 'Present';
        }
      }
      _updateCounters();
    });
  }

  void _updateCounters() {
    _presentCount = 0;
    _absentCount = 0;
    _overtimeCount = 0;

    for (var status in _attendanceMap.values) {
      if (status == 'Absent') {
        _absentCount++;
      } else if (status == 'Overtime') {
        _overtimeCount++;
      } else {
        _presentCount++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engineer Attendance'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
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
            tooltip: 'Attendance Reports',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading Attendance Data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Date and Stats Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'EEEE, MMMM d',
                                ).format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('yyyy').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
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
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_engineers.length} Engineers',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            count: _presentCount,
                            label: 'Present',
                            color: Colors.green,
                            icon: Icons.check_circle,
                          ),
                          _buildStatCard(
                            count: _absentCount,
                            label: 'Absent',
                            color: Colors.red,
                            icon: Icons.cancel,
                          ),
                          _buildStatCard(
                            count: _overtimeCount,
                            label: 'Overtime',
                            color: Colors.orange,
                            icon: Icons.access_time,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search engineers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                // Tab Bar with Actions
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context).primaryColor,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey.shade700,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cancel, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Absent'),
                                  if (_absentCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$_absentCount',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Overtime'),
                                  if (_overtimeCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$_overtimeCount',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _selectAllInTab(
                              _tabController.index == 0 ? 'Absent' : 'Overtime',
                            ),
                            icon: const Icon(Icons.checklist, size: 16),
                            label: const Text('Select All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _clearAllInTab(
                              _tabController.index == 0 ? 'Absent' : 'Overtime',
                            ),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Engineers List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEngineersContent('Absent'),
                      _buildEngineersContent('Overtime'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveAttendance,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isLoading ? 'SAVING...' : 'SAVE ATTENDANCE',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showRemarksDialog(String username) {
    final TextEditingController controller = TextEditingController(
      text: _remarksMap[username] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remarks for ${username.toUpperCase()}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter details...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _remarksMap[username] = controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required int count,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineersContent(String tabType) {
    final filteredEngineers = _engineers
        .where(
          (eng) => eng['username'].toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();

    if (filteredEngineers.isEmpty) {
      return _buildEmptyState();
    }

    return _isGridView
        ? _buildEngineersGrid(filteredEngineers, tabType)
        : _buildEngineersList(filteredEngineers, tabType);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No engineers found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineersGrid(
    List<Map<String, dynamic>> engineers,
    String tabType,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: engineers.length,
      itemBuilder: (context, index) {
        final engineer = engineers[index];
        return _buildEngineerGridCard(engineer, tabType);
      },
    );
  }

  Widget _buildEngineersList(
    List<Map<String, dynamic>> engineers,
    String tabType,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: engineers.length,
      itemBuilder: (context, index) {
        final engineer = engineers[index];
        return _buildEngineerCard(engineer, tabType);
      },
    );
  }

  Widget _buildEngineerGridCard(Map<String, dynamic> engineer, String tabType) {
    final username = engineer['username'];
    final currentStatus = _attendanceMap[username] ?? 'Present';
    final isChecked = currentStatus == tabType;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isChecked
              ? (tabType == 'Absent' ? Colors.red : Colors.orange).withOpacity(
                  0.5,
                )
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _attendanceMap[username] = isChecked ? 'Present' : tabType;
              _updateCounters();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.1),
                            Theme.of(context).primaryColor.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          username.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    if (isChecked)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: tabType == 'Absent'
                                ? Colors.red
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  username.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  engineer['role'] ?? 'Engineer',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (isChecked)
                  GestureDetector(
                    onTap: () => _showRemarksDialog(username),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (tabType == 'Absent'
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50)
                                .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (tabType == 'Absent' ? Colors.red : Colors.orange)
                                  .withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 14,
                            color: tabType == 'Absent'
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _remarksMap[username]?.isNotEmpty == true
                                ? 'Edit Remarks'
                                : 'Add Remarks',
                            style: TextStyle(
                              fontSize: 10,
                              color: tabType == 'Absent'
                                  ? Colors.red
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerCard(Map<String, dynamic> engineer, String tabType) {
    final username = engineer['username'];
    final currentStatus = _attendanceMap[username] ?? 'Present';
    final isChecked = currentStatus == tabType;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isChecked
              ? tabType == 'Absent'
                    ? Colors.red.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _attendanceMap[username] = isChecked ? 'Present' : tabType;
              _updateCounters();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.2),
                            Theme.of(context).primaryColor.withOpacity(0.4),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          username.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            engineer['email'] ?? 'No email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: tabType == 'Absent'
                            ? Colors.red
                            : Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        onChanged: (bool? value) {
                          setState(() {
                            _attendanceMap[username] = value == true
                                ? tabType
                                : 'Present';
                            _updateCounters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (isChecked)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (tabType == 'Absent'
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50)
                              .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tabType == 'Absent'
                            ? Colors.red.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              tabType == 'Absent'
                                  ? Icons.info_outline
                                  : Icons.access_time,
                              size: 16,
                              color: tabType == 'Absent'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tabType == 'Absent'
                                  ? 'Reason for Absence'
                                  : 'Overtime Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tabType == 'Absent'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: tabType == 'Absent'
                                ? 'Enter reason (optional)'
                                : 'Enter details (optional)',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (val) => _remarksMap[username] = val,
                          controller:
                              TextEditingController(
                                  text: _remarksMap[username] ?? '',
                                )
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset:
                                        (_remarksMap[username] ?? '').length,
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
      ),
    );
  }
}
