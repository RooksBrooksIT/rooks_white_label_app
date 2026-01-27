import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

class AmcCustomerHomePage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const AmcCustomerHomePage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  _AmcCustomerHomePageState createState() => _AmcCustomerHomePageState();
}

class _AmcCustomerHomePageState extends State<AmcCustomerHomePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerIdController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _mobileNumberController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customDeviceTypeController =
      TextEditingController();
  final TextEditingController _customDeviceBrandController =
      TextEditingController();

  late String deviceType = '';
  String deviceBrand = '';
  String deviceCondition = '';

  final List<String> jobTypes = ['Service', 'Delivery'];
  String jobType = '';

  List<String> deviceTypes = [];
  bool _isDeviceTypesLoading = false;

  List<String> deviceBrands = [];
  bool _isDeviceBrandsLoading = false;

  bool _isSubmitting = false;
  bool _isLoadingMobileNumber = true;

  @override
  void initState() {
    super.initState();

    _customerIdController = TextEditingController(text: widget.customerId);
    _customerNameController = TextEditingController(text: widget.customerName);
    _mobileNumberController = TextEditingController();

    // Fetch mobile number and device types
    _fetchMobileNumber();
    _fetchDeviceTypes();
  }

  Future<void> _fetchMobileNumber() async {
    setState(() {
      _isLoadingMobileNumber = true;
    });

    try {
      final docSnapshot = await FirestoreService.instance
          .collection('AMC_user')
          .doc(widget.customerId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final mobileNumber =
            data?['mobileNumber']?.toString() ??
            data?['Phone Number']?.toString() ??
            data?['contactNumber']?.toString() ??
            'Not available';

        _mobileNumberController.text = mobileNumber;
      } else {
        _mobileNumberController.text = 'Not found';
      }
    } catch (e) {
      print('Error fetching mobile number: $e');
      _mobileNumberController.text = 'Error loading';
    } finally {
      setState(() {
        _isLoadingMobileNumber = false;
      });
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerNameController.dispose();
    _mobileNumberController.dispose();
    _messageController.dispose();
    _addressController.dispose();
    _customDeviceTypeController.dispose();
    _customDeviceBrandController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceTypes() async {
    setState(() {
      _isDeviceTypesLoading = true;
    });
    try {
      final snapshot = await FirestoreService.instance
          .collection('deviceDetails')
          .get();
      final types = snapshot.docs
          .map((doc) => doc['deviceType']?.toString())
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      if (!types.contains('Others')) types.add('Others');

      setState(() {
        deviceTypes = types;
      });
    } catch (_) {
      setState(() {
        deviceTypes = ['Others'];
      });
    } finally {
      setState(() {
        _isDeviceTypesLoading = false;
      });
    }
  }

  Future<void> _fetchDeviceBrands(String deviceType) async {
    setState(() {
      _isDeviceBrandsLoading = true;
      deviceBrands = [];
    });

    try {
      String? collectionName;
      switch (deviceType.toLowerCase()) {
        case 'desktop':
          collectionName = 'desktopBrands';
          break;
        case 'laptop':
          collectionName = 'laptopBrands';
          break;
        case 'cctv':
          collectionName = 'cctvBrands';
          break;
        case 'projector':
          collectionName = 'projectorBrands';
          break;
        case 'printer':
          collectionName = 'printerBrands';
          break;
        default:
          collectionName = null;
      }

      if (collectionName != null) {
        final snapshot = await FirestoreService.instance
            .collection(collectionName)
            .get();
        final brands =
            snapshot.docs
                .map(
                  (doc) =>
                      doc['brandName']?.toString() ??
                      doc['name']?.toString() ??
                      doc['brand']?.toString() ??
                      '',
                )
                .where((b) => b.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        if (!brands.contains('Others')) brands.add('Others');

        setState(() {
          deviceBrands = brands;
        });
      } else {
        setState(() {
          deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
        });
      }
    } catch (_) {
      setState(() {
        deviceBrands = ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'];
      });
    } finally {
      setState(() {
        _isDeviceBrandsLoading = false;
      });
    }
  }

  List<String> get currentDeviceConditions {
    if (deviceType.toLowerCase() == 'cctv') {
      return [
        'Completely down',
        'Partially working',
        'Maintenance',
        'New Installation',
      ];
    }
    return ['Completely down', 'Partially working'];
  }

  Future<String> _generateBookingId() async {
    final counterRef = FirestoreService.instance
        .collection('counters')
        .doc('bookingId');
    return FirestoreService.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int lastId = 1700;
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['lastBookingId'] != null) {
          lastId = data['lastBookingId'] as int;
        }
      }
      final nextId = lastId + 1;
      transaction.set(counterRef, {'lastBookingId': nextId});
      return nextId.toString();
    });
  }

  void _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final bookingId = await _generateBookingId();
        final actualDeviceType = deviceType == 'Others'
            ? _customDeviceTypeController.text.trim()
            : deviceType;
        final actualDeviceBrand = deviceBrand == 'Others'
            ? _customDeviceBrandController.text.trim()
            : deviceBrand;

        Map<String, dynamic> customerData = {
          'id': _customerIdController.text,
          'bookingId': bookingId,
          'customerName': _customerNameController.text,
          'mobileNumber': _mobileNumberController.text,
          'address': _addressController.text,
          'categoryName': "",
          'timestamp': Timestamp.now(),
          'JobType': jobType,
        };

        if (jobType == 'Service') {
          customerData.addAll({
            'deviceType': actualDeviceType,
            'deviceBrand': actualDeviceBrand,
            'deviceCondition': deviceCondition,
            'message': _messageController.text,
          });
        } else if (jobType == 'Delivery') {
          customerData.addAll({'message': _descriptionController.text});
        }

        final adminData = Map<String, dynamic>.from(customerData);
        adminData['adminStatus'] = 'Open';
        adminData['customerStatus'] = 'Ticket Created';
        adminData['engineerStatus'] = 'Not Assigned';

        String docId = bookingId;

        await FirestoreService.instance
            .collection('customers')
            .doc(docId)
            .set(customerData);
        await FirestoreService.instance
            .collection('Admin_details')
            .doc(docId)
            .set(adminData);

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/success.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Details Submitted Successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our team will contact you soon.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool enabled = true,
    bool showLoading = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: enabled
                    ? Theme.of(context).cardColor
                    : Theme.of(context).disabledColor.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 15,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              maxLines: maxLines,
              enabled: enabled,
              validator:
                  validator ??
                  (v) => (v == null || v.isEmpty) ? '$label is required' : null,
              inputFormatters: inputFormatters,
            ),
            if (showLoading && _isLoadingMobileNumber)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> options,
    IconData icon,
    Function(String?) onChanged, {
    String? value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 15,
            ),
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          items: options
              .map(
                (val) => DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (v) =>
              (v == null || v.isEmpty) ? '$label is required' : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Service Request',
          style: TextStyle(
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              _buildTextField(
                'Customer ID',
                '',
                Icons.perm_identity,
                _customerIdController,
                enabled: false,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Customer Name',
                '',
                Icons.person,
                _customerNameController,
                enabled: false,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Mobile Number',
                '',
                Icons.phone,
                _mobileNumberController,
                enabled: false,
                showLoading: true,
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                'Job Type',
                jobTypes,
                Icons.work,
                (value) {
                  setState(() {
                    jobType = value ?? '';
                    if (jobType == 'Delivery') {
                      deviceType = '';
                      deviceBrand = '';
                      deviceCondition = '';
                      _messageController.clear();
                      _customDeviceTypeController.clear();
                      _customDeviceBrandController.clear();
                    } else {
                      _descriptionController.clear();
                    }
                  });
                },
                value: jobType.isNotEmpty ? jobType : null,
              ),
              if (jobType == 'Service') ...[
                const SizedBox(height: 20),
                _isDeviceTypesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDropdownField(
                        'Device Type',
                        deviceTypes,
                        Icons.devices,
                        (value) async {
                          setState(() {
                            deviceType = value ?? '';
                            if (deviceType != 'Others') {
                              _customDeviceTypeController.clear();
                            }
                            deviceBrand = '';
                            _customDeviceBrandController.clear();
                          });
                          if (value != null && value != 'Others') {
                            await _fetchDeviceBrands(value);
                          } else {
                            setState(() {
                              deviceBrands = [
                                'DELL',
                                'HP',
                                'MAC',
                                'LENOVO',
                                'ASUS',
                                'Others',
                              ];
                            });
                          }
                        },
                        value: deviceType.isNotEmpty ? deviceType : null,
                      ),
                if (deviceType == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                      'Custom Device Type',
                      'Enter your device type',
                      Icons.devices_other,
                      _customDeviceTypeController,
                    ),
                  ),
                const SizedBox(height: 20),
                _isDeviceBrandsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDropdownField(
                        'Device Brand',
                        deviceBrands.isNotEmpty
                            ? deviceBrands
                            : ['DELL', 'HP', 'MAC', 'LENOVO', 'ASUS', 'Others'],
                        Icons.branding_watermark,
                        (value) {
                          setState(() {
                            deviceBrand = value ?? '';
                            if (deviceBrand != 'Others') {
                              _customDeviceBrandController.clear();
                            }
                          });
                        },
                        value: deviceBrand.isNotEmpty ? deviceBrand : null,
                      ),
                if (deviceBrand == 'Others')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildTextField(
                      'Custom Device Brand',
                      'Enter your device brand',
                      Icons.branding_watermark,
                      _customDeviceBrandController,
                    ),
                  ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  'Device Condition',
                  currentDeviceConditions,
                  Icons.build,
                  (value) {
                    setState(() {
                      deviceCondition = value ?? '';
                    });
                  },
                  value: deviceCondition.isNotEmpty ? deviceCondition : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  'Message',
                  'Enter additional details',
                  Icons.message,
                  _messageController,
                  maxLines: 3,
                ),
              ],
              if (jobType == 'Delivery') ...[
                const SizedBox(height: 20),
                _buildTextField(
                  'Description',
                  'Enter delivery description',
                  Icons.description,
                  _descriptionController,
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              _buildTextField(
                'Address',
                'Enter your address',
                Icons.location_on,
                _addressController,
              ),
              const SizedBox(height: 30),
              Center(
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : GradientButton(onPressed: _handleSubmit, text: 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
