import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class AdminGeoLocationScreen extends StatefulWidget {
  final String engineerId;
  final String engineerName;
  final String? bookingDocId;

  const AdminGeoLocationScreen({
    super.key,
    required this.engineerId,
    required this.engineerName,
    this.bookingDocId,
  });

  @override
  State<AdminGeoLocationScreen> createState() => _AdminGeoLocationScreenState();
}

class _AdminGeoLocationScreenState extends State<AdminGeoLocationScreen> {
  // State variables
  latlong.LatLng? _lastLocation;
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  double _currentAccuracy = 0.0;
  bool _isOnline = false;
  DateTime? _lastUpdateTime;
  DateTime? _lastRTDBUpdateTime;
  int _updateCount = 0;
  bool _autoFollow = true;
  String? _assignedEmployeeName;
  String? _currentTicketStatus;

  StreamSubscription<rtdb.DatabaseEvent>? _engineerSubscription;
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>?
  _adminSubscription;
  final MapController _mapController = MapController();
  final List<latlong.LatLng> _pathHistory = [];
  String? _currentTrackingId;
  String? _currentTrackingName;

  // New variable to store engineers list
  List<Map<String, dynamic>> _engineersList = [];
  bool _isLoadingEngineers = false;

  String _sanitizePath(String path) {
    return path.replaceAll(RegExp(r'[.#$\[\]]'), '_');
  }

  @override
  void initState() {
    super.initState();
    _currentTrackingId = widget.engineerId;
    _currentTrackingName = widget.engineerName;
    _checkAuthAndListen();
    _loadEngineersList();
  }

  // Function to load engineers from Firestore
  Future<void> _loadEngineersList() async {
    if (mounted) {
      setState(() {
        _isLoadingEngineers = true;
      });
    }

    try {
      // Get engineers list under the current tenant
      final query = FirestoreService.instance
          .collection('EngineerLogin')
          .where('Username', isNotEqualTo: null);

      final snapshot = await query.get();

      final engineers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final username = data['Username']?.toString();

        if (username != null && username.isNotEmpty) {
          // Extract the parent document ID (Abishek_20260203, etc.)
          final parentDocId = doc.reference.parent.parent?.id ?? 'unknown';

          engineers.add({
            'id': username, // Using username as ID for tracking
            'username': username,
            'parentDocId': parentDocId,
            'fullPath': doc.reference.path,
          });
        }
      }

      // Remove duplicates based on username
      final uniqueEngineers = <Map<String, dynamic>>[];
      final seenUsernames = <String>{};

      for (final engineer in engineers) {
        final username = engineer['username'] as String;
        if (!seenUsernames.contains(username)) {
          seenUsernames.add(username);
          uniqueEngineers.add(engineer);
        }
      }

      if (mounted) {
        setState(() {
          _engineersList = uniqueEngineers;
          _isLoadingEngineers = false;
        });
      }

      debugPrint('Loaded ${_engineersList.length} engineers');
    } catch (e) {
      debugPrint('Error loading engineers: $e');
      if (mounted) {
        setState(() {
          _isLoadingEngineers = false;
        });
      }
    }
  }

  Future<void> _checkAuthAndListen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint(
          'AdminGeoLocationScreen: No session. Attempting Anonymous Auth...',
        );
        final cred = await FirebaseAuth.instance.signInAnonymously();
        debugPrint(
          'AdminGeoLocationScreen: Anonymous Auth successful. UID: ${cred.user?.uid}',
        );
      } else {
        debugPrint(
          'AdminGeoLocationScreen: Already authenticated as ${user.uid}',
        );
      }
    } catch (e) {
      debugPrint('AdminGeoLocationScreen: Anonymous Auth FATAL ERROR: $e');
      debugPrint(
        'Please check if "Anonymous" sign-in provider is enabled in Firebase Console.',
      );
    }
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _engineerSubscription?.cancel();
    _adminSubscription?.cancel();

    if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      _listenToEngineerLocation();
    }
    _listenToAdminDetails();
  }

  void _switchEngineer(String id, String name) {
    if (mounted) {
      setState(() {
        _currentTrackingId = id;
        _currentTrackingName = name;
        _lastLocation = null;
        _pathHistory.clear();
        _updateCount = 0;
        _currentSpeed = 0.0;
        _currentHeading = 0.0;
        _currentAccuracy = 0.0;
        _isOnline = false;
        _lastUpdateTime = null;
        _assignedEmployeeName = null;
        _currentTicketStatus = null;
        _autoFollow = true;
      });
      _listenForUpdates();

      // Show snackbar feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now tracking: $name'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _listenToAdminDetails() {
    _adminSubscription?.cancel();

    firestore.Query<Map<String, dynamic>> query;

    if (widget.bookingDocId != null && widget.bookingDocId!.isNotEmpty) {
      // If we have a specific booking, prioritize listening to it
      query = FirestoreService.instance
          .collection('Admin_details')
          .where(
            firestore.FieldPath.documentId,
            isEqualTo: widget.bookingDocId,
          );
    } else if (_currentTrackingId != null && _currentTrackingId!.isNotEmpty) {
      // Otherwise, track the latest record for the selected engineer
      query = FirestoreService.instance
          .collection('Admin_details')
          .where('assignedEmployee', isEqualTo: _currentTrackingId)
          .orderBy('timestamp', descending: true)
          .limit(1);
    } else {
      return;
    }

    _adminSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          debugPrint(
            'AdminGeoLocationScreen: No Admin_details found for tracking',
          );
          return;
        }

        final data = snapshot.docs.first.data();
        final dynamic latVal = data['lat'];
        final dynamic lngVal = data['lng'];
        final String? assignedEmployee = data['assignedEmployee']?.toString();
        final String? adminStatus = data['adminStatus']?.toString();

        if (mounted) {
          // If the assigned employee changes in the booking document, update tracking
          if (assignedEmployee != null &&
              assignedEmployee.isNotEmpty &&
              assignedEmployee != _currentTrackingId) {
            debugPrint(
              'AdminGeoLocationScreen: assignedEmployee changed from $_currentTrackingId to $assignedEmployee',
            );
            setState(() {
              _currentTrackingId = assignedEmployee;
              _currentTrackingName = assignedEmployee;
              _lastLocation = null;
              _pathHistory.clear();
              _updateCount = 0;
              _isOnline = false;
              _lastUpdateTime = null;
              _lastRTDBUpdateTime = null;
            });

            // Restart the engineer location listener
            _listenToEngineerLocation();

            // Notify user of the change
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-switched tracking to: $assignedEmployee'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          setState(() {
            _assignedEmployeeName = assignedEmployee;
            _currentTicketStatus = adminStatus;

            if (latVal != null && lngVal != null) {
              final double lat = (latVal as num).toDouble();
              final double lng = (lngVal as num).toDouble();
              final newPos = latlong.LatLng(lat, lng);

              // Only update from Firestore if RTDB hasn't updated recently (last 10 seconds)
              // or if this is the first location we're receiving.
              final bool shouldUpdateFromFirestore =
                  _lastRTDBUpdateTime == null ||
                  DateTime.now().difference(_lastRTDBUpdateTime!).inSeconds >
                      10;

              if (shouldUpdateFromFirestore &&
                  (_lastLocation == null || _lastLocation != newPos)) {
                _lastLocation = newPos;
                _updateCount++;
                _pathHistory.add(newPos);
                if (_pathHistory.length > 200) _pathHistory.removeAt(0);

                if (_autoFollow) {
                  _mapController.move(newPos, _mapController.camera.zoom);
                }
              }
            }
          });
        }
      },
      onError: (error) {
        debugPrint(
          'AdminGeoLocationScreen: Error listening to Admin_details: $error',
        );
      },
    );
  }

  void _listenToEngineerLocation() {
    _engineerSubscription?.cancel();
    if (_currentTrackingId == null || _currentTrackingId!.isEmpty) return;
    final sanitizedId = _sanitizePath(_currentTrackingId!);
    final tenantId = ThemeService.instance.databaseName;
    final dbRef = rtdb.FirebaseDatabase.instance.ref(
      '$tenantId/engineers/$sanitizedId',
    );

    _engineerSubscription = dbRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;
        if (data == null) return;

        final engineerData = Map<String, dynamic>.from(data as Map);
        final locationData = engineerData['location'] != null
            ? Map<String, dynamic>.from(engineerData['location'] as Map)
            : null;

        if (mounted) {
          setState(() {
            _isOnline = engineerData['isOnline'] ?? false;

            if (locationData != null) {
              final double lat = (locationData['lat'] as num).toDouble();
              final double lng = (locationData['lng'] as num).toDouble();
              final newPos = latlong.LatLng(lat, lng);

              // Check if position changed
              if (_lastLocation == null || _lastLocation != newPos) {
                _lastLocation = newPos;
                _updateCount++;
                _pathHistory.add(newPos);
                if (_pathHistory.length > 200) _pathHistory.removeAt(0);

                // Auto-follow logic
                if (_autoFollow) {
                  _mapController.move(newPos, _mapController.camera.zoom);
                }
              }

              _currentSpeed = (locationData['speed'] as num? ?? 0.0).toDouble();
              _currentHeading = (locationData['heading'] as num? ?? 0.0)
                  .toDouble();
              _currentAccuracy = (locationData['accuracy'] as num? ?? 0.0)
                  .toDouble();
              _lastRTDBUpdateTime = DateTime.now();
              _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(
                locationData['lastUpdate'] ??
                    locationData['timestamp'] ??
                    DateTime.now().millisecondsSinceEpoch,
              );
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to location: $error');
      },
    );
  }

  void _centerOnEngineer() {
    if (_lastLocation != null) {
      _mapController.move(_lastLocation!, 16.5);
      setState(() => _autoFollow = true);
    }
  }

  void _zoomIn() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom + 1,
  );
  void _zoomOut() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom - 1,
  );

  @override
  void dispose() {
    _engineerSubscription?.cancel();
    _adminSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTrackingName != null && _currentTrackingName!.isNotEmpty
                  ? "Tracking: $_currentTrackingName"
                  : "Select an Engineer",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _isOnline ? "Online" : "Offline",
              style: TextStyle(
                fontSize: 12,
                color: _isOnline ? Colors.greenAccent : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A), // Deep Blue
        elevation: 0,
        actions: [
          // Add a refresh button to reload engineers list
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEngineersList,
            tooltip: 'Refresh engineers list',
          ),
          // Add engineers list button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.people),
                if (_engineersList.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _engineersList.length.toString(),
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
            onPressed: _showEngineerSelectionSheet,
            tooltip: 'Select Engineer',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildFloatingControls(),
          _buildEngineerOverlay(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _lastLocation ?? const latlong.LatLng(12.9716, 77.5946);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16.5,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _autoFollow) {
            setState(() => _autoFollow = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rooks.charity_app',
        ),
        if (_pathHistory.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _pathHistory,
                strokeWidth: 4,
                color: Colors.blue.withOpacity(0.6),
              ),
            ],
          ),
        if (_lastLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _lastLocation!,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        _assignedEmployeeName ??
                            _currentTrackingName ??
                            "Unknown",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: _currentHeading * (3.14159 / 180),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (_lastLocation != null && _currentAccuracy > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _lastLocation!,
                radius: _currentAccuracy,
                useRadiusInMeter: true,
                color: Colors.blue.withOpacity(0.1),
                borderColor: Colors.blue.withOpacity(0.3),
                borderStrokeWidth: 1,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          _buildMapButton(Icons.add, _zoomIn),
          const SizedBox(height: 8),
          _buildMapButton(Icons.remove, _zoomOut),
          const SizedBox(height: 16),
          _buildMapButton(
            Icons.my_location,
            _centerOnEngineer,
            color: _autoFollow ? Colors.blue : Colors.white,
          ),
        ],
      ),
    );
  }

  void _showEngineerSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Engineer to Track",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              if (_isLoadingEngineers)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_engineersList.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No engineers found",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Make sure engineers have logged in",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEngineersList,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _engineersList.length,
                    itemBuilder: (context, index) {
                      final engineer = _engineersList[index];
                      final username = engineer['username'] as String;
                      final parentDocId = engineer['parentDocId'] as String;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 0,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                username.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "ID: $parentDocId",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: _currentTrackingId == username
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Tracking",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                          onTap: () {
                            _switchEngineer(username, username);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              if (!_isLoadingEngineers && _engineersList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "${_engineersList.length} engineer(s) found",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapButton(
    IconData icon,
    VoidCallback onPressed, {
    Color color = Colors.white,
  }) {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: color,
      child: Icon(
        icon,
        color: color == Colors.white ? Colors.black87 : Colors.white,
      ),
    );
  }

  Widget _buildEngineerOverlay() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.engineering, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _assignedEmployeeName ??
                            _currentTrackingName ??
                            "Select Engineer",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Last updated: ${_lastUpdateTime != null ? DateFormat('HH:mm:ss').format(_lastUpdateTime!) : 'Never'}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIndicator(),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoStat(
                  Icons.speed,
                  "Speed",
                  "${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h",
                ),
                _buildInfoStat(Icons.sync, "Updates", "$_updateCount"),
                _buildInfoStat(
                  Icons.route,
                  "Distance",
                  "~${(_pathHistory.length * 0.01).toStringAsFixed(2)} km",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOnline ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Text(
        _currentTicketStatus?.toUpperCase() ?? (_isOnline ? "LIVE" : "OFFLINE"),
        style: TextStyle(
          color: _isOnline ? Colors.green.shade700 : Colors.red.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
      ],
    );
  }
}
