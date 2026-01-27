import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import 'package:open_file/open_file';

class CustomerReportGenerator extends StatefulWidget {
  const CustomerReportGenerator({super.key});

  @override
  _CustomerReportGeneratorState createState() =>
      _CustomerReportGeneratorState();
}

class _CustomerReportGeneratorState extends State<CustomerReportGenerator> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? resultData;
  List<Map<String, dynamic>>? multipleResults;
  bool _loading = false;
  String _debugInfo = '';

  // Track selected rows for multiple results
  final Map<int, bool> _selectedRows = {};
  bool _allSelected = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  Future<void> _fetchData(String input) async {
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter Customer ID, Phone, or Booking ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      resultData = null;
      multipleResults = null;
      _selectedRows.clear();
      _allSelected = false;
      _debugInfo = 'Searching for: "$input"';
    });

    try {
      print('Searching for: $input');

      // Try searching in all three fields
      final List<QuerySnapshot> snapshots = await Future.wait([
        FirestoreService.instance
            .collection('Admin_details')
            .where('id', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Admin_details')
            .where('mobileNumber', isEqualTo: input)
            .get(),
        FirestoreService.instance
            .collection('Admin_details')
            .where('bookingId', isEqualTo: input)
            .get(),
      ]);

      if (snapshots[1].docs.isNotEmpty) {
        // Found multiple entries by mobileNumber
        multipleResults = snapshots[1].docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        // Initialize all checkboxes as unselected
        for (int i = 0; i < multipleResults!.length; i++) {
          _selectedRows[i] = false;
        }

        setState(() {
          _debugInfo =
              'Found ${multipleResults!.length} results for mobileNumber: $input';
          resultData = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${multipleResults!.length} entries for Mobile Number',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Check for id or bookingId match (only single record)
        QuerySnapshot? foundSnapshot;
        String foundInField = '';

        for (int i in [0, 2]) {
          if (snapshots[i].docs.isNotEmpty) {
            foundSnapshot = snapshots[i];
            foundInField = (i == 0) ? 'Id' : 'BookingId';
            break;
          }
        }

        if (foundSnapshot != null) {
          final data = foundSnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            resultData = data;
            multipleResults = null;
            _selectedRows.clear();
            _allSelected = false;
            // _debugInfo =
            //     'Found in field: $foundInField\nTotal fields: ${data.length}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data found successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            resultData = null;
            multipleResults = null;
            _selectedRows.clear();
            _allSelected = false;
            _debugInfo =
                'No documents found in any field\nSearched: Id, MobileNumber, BookingId';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data found for "$input"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        resultData = null;
        multipleResults = null;
        _selectedRows.clear();
        _allSelected = false;
        _debugInfo = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _toggleAllSelection() {
    setState(() {
      _allSelected = !_allSelected;
      if (multipleResults != null) {
        for (int i = 0; i < multipleResults!.length; i++) {
          _selectedRows[i] = _allSelected;
        }
      }
    });
  }

  void _toggleRowSelection(int index) {
    setState(() {
      _selectedRows[index] = !(_selectedRows[index] ?? false);

      // Update "Select All" checkbox state
      if (multipleResults != null) {
        _allSelected = _selectedRows.values.every((isSelected) => isSelected);
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedRecords() {
    if (multipleResults != null) {
      List<Map<String, dynamic>> selected = [];
      for (int i = 0; i < multipleResults!.length; i++) {
        if (_selectedRows[i] == true) {
          selected.add(multipleResults![i]);
        }
      }
      return selected;
    } else if (resultData != null) {
      return [resultData!];
    }
    return [];
  }

  int get _selectedCount {
    return _selectedRows.values.where((isSelected) => isSelected).length;
  }

  Future<void> _generatePdf() async {
    final selectedRecords = _getSelectedRecords();

    if (selectedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one record to generate PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      final pdf = pw.Document();

      // Load and embed the logo
      final logoImage = pw.MemoryImage(
        (await rootBundle.load('assets/RooksLogo.png')).buffer.asUint8List(),
      );

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with Logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CUSTOMER SERVICE REPORT',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Service Company',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.normal,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Generated on: ${DateTime.now().toString().split(' ')[0]}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2, color: PdfColors.blue400),
                pw.SizedBox(height: 20),

                // Report Summary
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'REPORT SUMMARY',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total Selected Records: ${selectedRecords.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.blue700,
                        ),
                      ),
                      if (multipleResults != null)
                        pw.Text(
                          'Filtered from ${multipleResults!.length} total records',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Customer Details Table Title
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'SELECTED CUSTOMER SERVICE DETAILS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),

                // Table with selected details only
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4),
                      topRight: pw.Radius.circular(4),
                    ),
                  ),
                  cellHeight: 25,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                    6: pw.Alignment.centerLeft,
                    7: pw.Alignment.centerLeft,
                    8: pw.Alignment.centerRight,
                  },
                  headers: [
                    'ID',
                    'CUSTOMER NAME',
                    'BOOKING ID',
                    'DEVICE BRAND',
                    'DEVICE TYPE',
                    'DEVICE CONDITION',
                    'ADMIN STATUS',
                    'ADDRESS',
                    'AMOUNT',
                  ],
                  data: _getPdfTableData(selectedRecords),
                ),

                pw.SizedBox(height: 25),
                pw.Divider(thickness: 1, color: PdfColors.grey300),

                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Page 1 of 1',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Confidential - For Internal Use Only',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File(
        "${output.path}/customer_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await file.writeAsBytes(await pdf.save());

      // Open the PDF file
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generated with $_selectedCount selected records!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('PDF Generation Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<List<String>> _getPdfTableData(List<Map<String, dynamic>> records) {
    final fields = [
      'id',
      'customerName',
      'bookingId',
      'deviceBrand',
      'deviceType',
      'deviceCondition',
      'adminStatus',
      'address',
      'amount',
    ];

    List<List<String>> data = [];

    for (var record in records) {
      List<String> row = [];
      for (var key in fields) {
        row.add(record[key]?.toString() ?? 'N/A');
      }
      data.add(row);
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Customer Report Generator',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Card
            Card(
              elevation: 8,
              shadowColor: primaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor,
                      Theme.of(context).primaryColorLight.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search, color: primaryColor, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Find Customer Records',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Enter Customer ID, Phone, or Booking ID',
                          labelStyle: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          prefixIcon: Icon(
                            Icons.person_search,
                            color: primaryColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onSubmitted: (value) {
                          _fetchData(value.trim());
                        },
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => _fetchData(_controller.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            shadowColor: primaryColor.withOpacity(0.4),
                          ),
                          child: _loading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.manage_search, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Search & Generate Report',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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

            SizedBox(height: 20),

            // Debug Info
            if (_debugInfo.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  _debugInfo,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),

            SizedBox(height: 20),

            // Selection Info Bar (when multiple results)
            if (multipleResults != null && multipleResults!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedCount > 0
                      ? Theme.of(context).primaryColorLight.withOpacity(0.2)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedCount > 0
                        ? Theme.of(context).primaryColorLight
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_selectedCount of ${multipleResults!.length} records selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedCount > 0
                            ? primaryColor
                            : Theme.of(context).hintColor,
                      ),
                    ),
                    if (multipleResults!.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            'Select All',
                            style: TextStyle(fontSize: 12, color: primaryColor),
                          ),
                          SizedBox(width: 8),
                          Checkbox(
                            value: _allSelected,
                            onChanged: (value) => _toggleAllSelection(),
                            activeColor: primaryColor,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            SizedBox(height: 10),

            // Results Section
            Expanded(
              child: multipleResults != null && multipleResults!.isNotEmpty
                  ? _buildMultipleResultsTable()
                  : resultData == null
                  ? _buildEmptyState()
                  : _buildSingleResultTable(),
            ),

            SizedBox(height: 20),

            // PDF Generation Button
            if ((resultData != null) ||
                (multipleResults != null && multipleResults!.isNotEmpty))
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generatePdf,
                  icon: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.picture_as_pdf, size: 24),
                  label: Text(
                    _loading
                        ? 'Generating PDF...'
                        : multipleResults != null
                        ? 'Generate PDF ($_selectedCount selected)'
                        : 'Generate PDF Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCount > 0 || resultData != null
                        ? Colors.red[600]
                        : Theme.of(context).disabledColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: (_selectedCount > 0 || resultData != null)
                        ? Theme.of(context).colorScheme.error.withOpacity(0.3)
                        : Theme.of(context).disabledColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColorLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 60,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Data Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Try searching with Customer ID, Phone Number, or Booking ID',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMultipleResultsTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.green, size: 24),
                SizedBox(width: 10),
                Text(
                  'Multiple Records Found (${multipleResults!.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Color(0xFF0B3470),
                      ),
                      headingTextStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.blue[100];
                        }
                        return Colors.white;
                      }),
                      border: TableBorder.all(
                        color: Colors.grey[300]!,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(width: 40, child: Text('SELECT')),
                        ),
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('CUSTOMER NAME')),
                        DataColumn(label: Text('BOOKING ID')),
                        DataColumn(label: Text('DEVICE BRAND')),
                        DataColumn(label: Text('DEVICE TYPE')),
                        DataColumn(label: Text('CONDITION')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('ADDRESS')),
                        DataColumn(label: Text('AMOUNT'), numeric: true),
                      ],
                      rows: multipleResults!.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> record = entry.value;
                        bool isSelected = _selectedRows[index] ?? false;

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (selected) {
                            _toggleRowSelection(index);
                          },
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  _toggleRowSelection(index);
                                },
                                activeColor: primaryColor,
                              ),
                            ),
                            DataCell(Text(record['id']?.toString() ?? 'N/A')),
                            DataCell(
                              Text(record['customerName']?.toString() ?? 'N/A'),
                            ),
                            DataCell(
                              Text(record['bookingId']?.toString() ?? 'N/A'),
                            ),
                            DataCell(
                              Text(record['deviceBrand']?.toString() ?? 'N/A'),
                            ),
                            DataCell(
                              Text(record['deviceType']?.toString() ?? 'N/A'),
                            ),
                            DataCell(
                              Text(
                                record['deviceCondition']?.toString() ?? 'N/A',
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    record['adminStatus']?.toString(),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record['adminStatus']?.toString() ?? 'N/A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  record['address']?.toString() ?? 'N/A',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                record['amount']?.toString() ?? 'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleResultTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 24),
                SizedBox(width: 10),
                Text(
                  'Customer Record Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Color(0xFF0B3470)),
                    headingTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    border: TableBorder.all(
                      color: Colors.grey[300]!,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    columns: [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('CUSTOMER NAME')),
                      DataColumn(label: Text('BOOKING ID')),
                      DataColumn(label: Text('DEVICE BRAND')),
                      DataColumn(label: Text('DEVICE TYPE')),
                      DataColumn(label: Text('CONDITION')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('ADDRESS')),
                      DataColumn(label: Text('AMOUNT'), numeric: true),
                    ],
                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            Text(resultData?['id']?.toString() ?? 'N/A'),
                          ),
                          DataCell(
                            Text(
                              resultData?['customerName']?.toString() ?? 'N/A',
                            ),
                          ),
                          DataCell(
                            Text(resultData?['bookingId']?.toString() ?? 'N/A'),
                          ),
                          DataCell(
                            Text(
                              resultData?['deviceBrand']?.toString() ?? 'N/A',
                            ),
                          ),
                          DataCell(
                            Text(
                              resultData?['deviceType']?.toString() ?? 'N/A',
                            ),
                          ),
                          DataCell(
                            Text(
                              resultData?['deviceCondition']?.toString() ??
                                  'N/A',
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  resultData?['adminStatus']?.toString(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                resultData?['adminStatus']?.toString() ?? 'N/A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                resultData?['address']?.toString() ?? 'N/A',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              resultData?['amount']?.toString() ?? 'N/A',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
