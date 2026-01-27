import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminDeviceConfigurationPage extends StatefulWidget {
  const AdminDeviceConfigurationPage({super.key});

  @override
  State<AdminDeviceConfigurationPage> createState() =>
      _AdminDeviceConfigurationPageState();
}

class _AdminDeviceConfigurationPageState
    extends State<AdminDeviceConfigurationPage> {
  final TextEditingController _deviceTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirestoreService _firestore = FirestoreService.instance;
  bool _isLoading = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void dispose() {
    _deviceTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _deleteDevice(String deviceType) async {
    try {
      await _firestore.collection('deviceDetails').doc(deviceType).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device "$deviceType" deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting device: $e')));
    }
  }

  Future<void> _editDevice(String deviceType, String currentDescription) async {
    final TextEditingController editDeviceTypeController =
        TextEditingController(text: deviceType);
    final TextEditingController editDescriptionController =
        TextEditingController(text: currentDescription);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            double dialogWidth = constraints.maxWidth > 500
                ? 500
                : constraints.maxWidth * 0.9;
            return Dialog(
              child: Container(
                width: dialogWidth,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Device',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: editDeviceTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Device Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: editDescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final newDeviceType = editDeviceTypeController.text
                                .trim();
                            final newDescription = editDescriptionController
                                .text
                                .trim();
                            if (newDeviceType.isNotEmpty &&
                                newDescription.isNotEmpty) {
                              // If device type changed, delete old doc and create new one
                              if (newDeviceType != deviceType) {
                                final doc = await _firestore
                                    .collection('deviceDetails')
                                    .doc(deviceType)
                                    .get();
                                if (doc.exists) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  data['deviceType'] = newDeviceType;
                                  data['description'] = newDescription;
                                  await _firestore
                                      .collection('deviceDetails')
                                      .doc(deviceType)
                                      .delete();
                                  await _firestore
                                      .collection('deviceDetails')
                                      .doc(newDeviceType)
                                      .set(data);
                                }
                              } else {
                                await _firestore
                                    .collection('deviceDetails')
                                    .doc(deviceType)
                                    .update({'description': newDescription});
                              }
                              Navigator.of(context).pop(true);
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Device "${editDeviceTypeController.text.trim()}" updated successfully',
          ),
        ),
      );
    }
  }

  void _showDeviceOptions(String deviceType, String description) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                deviceType,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 400) {
                    // Vertical layout for small screens
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _editDevice(deviceType, description);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            onPressed: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Device'),
                                  content: const Text(
                                    'Are you sure you want to delete this device? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (shouldDelete == true) {
                                Navigator.of(context).pop();
                                await _deleteDevice(deviceType);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Horizontal layout for larger screens
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _editDevice(deviceType, description);
                          },
                        ),
                        OutlinedButton.icon(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Device'),
                                content: const Text(
                                  'Are you sure you want to delete this device? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldDelete == true) {
                              Navigator.of(context).pop();
                              await _deleteDevice(deviceType);
                            }
                          },
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Gets the next incremental deviceId like DE001, DE002, etc.
  Future<String> _getNextDeviceId() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('deviceDetails')
        .get();

    int maxNumber = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deviceId = data['deviceId'] as String?;
      if (deviceId != null && deviceId.startsWith('DE')) {
        final numberPart = deviceId.substring(2);
        final num = int.tryParse(numberPart) ?? 0;
        if (num > maxNumber) maxNumber = num;
      }
    }

    final nextNumber = maxNumber + 1;
    return 'DE${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _addDevice() async {
    final String deviceType = _deviceTypeController.text.trim();
    final String description = _descriptionController.text.trim();

    if (deviceType.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final nextDeviceId = await _getNextDeviceId();

      final Map<String, dynamic> deviceData = {
        'deviceType': deviceType,
        'description': description,
        'deviceId': nextDeviceId,
      };

      // Save document with deviceType as document ID
      await _firestore
          .collection('deviceDetails')
          .doc(deviceType)
          .set(deviceData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device "$deviceType" added with ID $nextDeviceId'),
        ),
      );

      _deviceTypeController.clear();
      _descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding device: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearFields() {
    _deviceTypeController.clear();
    _descriptionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text(
          'Device Configuration',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmallScreen = constraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
            child: Column(
              children: [
                Icon(
                  Icons.devices,
                  color: Colors.white,
                  size: isSmallScreen ? 40 : 50,
                ),
                SizedBox(height: isSmallScreen ? 8 : 10),
                const Text(
                  'Device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 25),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _deviceTypeController,
                          decoration: InputDecoration(
                            labelText: 'Device Type',
                            hintText: 'Enter device type',
                            prefixIcon: const Icon(Icons.devices_other),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 20),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Enter description',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 30),
                        isSmallScreen
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _addDevice,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.add),
                                      label: Text(
                                        _isLoading ? 'Adding...' : 'Add Device',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _clearFields,
                                      icon: const Icon(Icons.clear),
                                      label: const Text('Clear'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _clearFields,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(color: primaryColor),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _addDevice,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.add),
                                    label: Text(
                                      _isLoading ? 'Adding...' : 'Add Device',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                // Display deviceDetails collection as desktop cards
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'All Devices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('deviceDetails').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text(
                        'No devices found.',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    final docs = snapshot.data!.docs;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isSmallScreen
                            ? 1
                            : constraints.maxWidth > 900
                            ? 4
                            : constraints.maxWidth > 600
                            ? 3
                            : 2,
                        childAspectRatio: isSmallScreen ? 1.8 : 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final deviceType = data['deviceType'] ?? '';
                        final description = data['description'] ?? '';
                        final deviceId = data['deviceId'] ?? '';
                        return InkWell(
                          onTap: () =>
                              _showDeviceOptions(deviceType, description),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Theme.of(context).cardColor,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.devices_other,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          deviceType,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.description,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    deviceId,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
