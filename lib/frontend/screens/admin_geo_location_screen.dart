import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

class AdminGeoLocationScreen extends StatefulWidget {
  final String engineerId;
  final String engineerName;

  const AdminGeoLocationScreen({
    super.key,
    required this.engineerId,
    required this.engineerName,
  });

  @override
  State<AdminGeoLocationScreen> createState() => _AdminGeoLocationScreenState();
}

class _AdminGeoLocationScreenState extends State<AdminGeoLocationScreen> {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  String _status = "Not Tracking";
  int _updateCount = 0;
  DateTime? _lastUpdate;

  // Map controller - initialize directly
  final MapController _mapController = MapController();
  List<latlong.LatLng> _pathHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        final bgStatus = await Permission.locationAlways.request();
        if (bgStatus.isGranted) {
          await _startTracking();
        } else {
          _showPermissionDialog();
        }
      } else {
        _showPermissionDialog();
      }
    } catch (e) {
      print("Permission error: $e");
      // For testing, start tracking anyway
      if (mounted) {
        await _startTracking();
      }
    }
  }

  Future<void> _startTracking() async {
    await _stopTracking();

    setState(() {
      _status = "Starting tracking...";
    });

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _updateFirebaseLocation(_currentPosition!);
    } catch (e) {
      print("Error getting initial position: $e");
      setState(() {
        _status = "Error getting location";
      });
    }

    // Start listening to position updates
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10, // Update every 10 meters
            timeLimit: Duration(seconds: 5), // Max interval
          ),
        ).listen(
          (Position position) {
            _updateFirebaseLocation(position);
          },
          onError: (error) {
            print("Location stream error: $error");
            if (mounted) {
              setState(() {
                _status = "Error: ${error.toString()}";
              });
            }
          },
        );

    if (mounted) {
      setState(() {
        _isTracking = true;
        _status = "Live Tracking Active";
      });
    }
  }

  Future<void> _updateFirebaseLocation(Position position) async {
    final dbRef = FirebaseDatabase.instance.ref();

    try {
      await dbRef.child('engineers/${widget.engineerId}').update({
        'name': widget.engineerName,
        'status': 'on_the_way',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'location': {
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
        },
      });

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _updateCount++;
          _lastUpdate = DateTime.now();

          // Add to path history for drawing route
          final newLatLng = latlong.LatLng(
            position.latitude,
            position.longitude,
          );
          _pathHistory.add(newLatLng);

          // Keep only last 100 points for performance
          if (_pathHistory.length > 100) {
            _pathHistory.removeAt(0);
          }
        });
      }

      // Move map to current location
      _mapController.move(
        latlong.LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } catch (e) {
      print("Error updating Firebase: $e");
    }
  }

  Future<void> _stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;

    if (mounted) {
      setState(() {
        _isTracking = false;
        _status = "Tracking Stopped";
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text(
          "This app needs location permission to track your position. "
          "Please enable location permission in settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _centerMapOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0, // Zoom level
      );
    }
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Engineer Tracking",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.orange,
        actions: [
          if (_currentPosition != null)
            IconButton(
              onPressed: _centerMapOnMyLocation,
              icon: const Icon(Icons.my_location),
              tooltip: "Center on my location",
            ),
        ],
      ),
      body: Column(
        children: [
          // Map Section - Takes 60% of screen
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                _buildMap(),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        onPressed: _zoomIn,
                        heroTag: 'zoomIn',
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        onPressed: _zoomOut,
                        heroTag: 'zoomOut',
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isTracking ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTracking ? "LIVE TRACKING" : "OFFLINE",
                          style: GoogleFonts.inter(
                            fontSize: 12,
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

          // Info Section - Takes 40% of screen
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.grey[50],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEngineerInfoCard(),
                    const SizedBox(height: 12),
                    _buildLocationInfoCard(),
                    const SizedBox(height: 12),
                    _buildTrackingButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final currentLatLng = _currentPosition != null
        ? latlong.LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
        : const latlong.LatLng(12.9716, 77.5946); // Default to Bangalore

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLatLng,
        initialZoom: 16.0,
        maxZoom: 18,
        minZoom: 5,
        onMapReady: () {
          if (_currentPosition != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _centerMapOnMyLocation();
            });
          }
        },
      ),
      children: [
        // OpenStreetMap Tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.engineer_tracking',
          maxZoom: 19,
          subdomains: const ['a', 'b', 'c'],
        ),

        // Path History (route line)
        if (_pathHistory.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _pathHistory,
                color: Colors.orange.withOpacity(0.7),
                strokeWidth: 3.0,
                borderColor: Colors.orange.withOpacity(0.9),
                borderStrokeWidth: 1.0,
              ),
            ],
          ),

        // Current Location Marker
        MarkerLayer(
          markers: [
            Marker(
              point: currentLatLng,
              width: 70,
              height: 70,
              child: _buildLocationMarker(),
            ),
          ],
        ),

        // Accuracy Circle
        if (_currentPosition != null && _currentPosition!.accuracy > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: currentLatLng,
                color: Colors.orange.withOpacity(0.1),
                borderColor: Colors.orange.withOpacity(0.3),
                borderStrokeWidth: 1.0,
                useRadiusInMeter: true,
                radius: _currentPosition!.accuracy,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing effect for live tracking
        if (_isTracking)
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.2),
            ),
          ),

        // Main marker circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isTracking ? Colors.orange : Colors.grey[400]!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.engineering,
              size: 20,
              color: _isTracking ? Colors.orange : Colors.grey[600]!,
            ),
          ),
        ),

        // Direction arrow (if heading available)
        if (_currentPosition != null && _currentPosition!.heading > 0)
          Positioned(
            top: -20,
            child: Transform.rotate(
              angle: _currentPosition!.heading * (3.14159265359 / 180),
              child: Icon(Icons.arrow_upward, color: Colors.orange, size: 20),
            ),
          ),

        // Speed indicator (if moving)
        if (_currentPosition != null && _currentPosition!.speed > 1)
          Positioned(
            bottom: -25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "${(_currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEngineerInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.engineerName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${widget.engineerId}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isTracking
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isTracking
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isTracking ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isTracking ? "ACTIVE" : "INACTIVE",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isTracking ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.update,
                  "Updates",
                  _updateCount.toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  Icons.route,
                  "Path Points",
                  _pathHistory.length.toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  _isTracking ? Icons.send : Icons.send_and_archive,
                  "Status",
                  _status.split(":")[0],
                  _isTracking ? Colors.orange : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildLocationInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  "CURRENT LOCATION",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              _buildLocationInfoRow(
                Icons.explore,
                "Latitude",
                _currentPosition!.latitude.toStringAsFixed(6),
              ),
              _buildLocationInfoRow(
                Icons.explore,
                "Longitude",
                _currentPosition!.longitude.toStringAsFixed(6),
              ),
              _buildLocationInfoRow(
                Icons.home,
                "Accuracy",
                "${_currentPosition!.accuracy.toStringAsFixed(1)} meters",
              ),
              if (_currentPosition!.speed > 0)
                _buildLocationInfoRow(
                  Icons.speed,
                  "Speed",
                  "${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h",
                ),
              if (_currentPosition!.heading >= 0)
                _buildLocationInfoRow(
                  Icons.compass_calibration,
                  "Heading",
                  "${_currentPosition!.heading.toStringAsFixed(0)}°",
                ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              if (_lastUpdate != null)
                _buildLocationInfoRow(
                  Icons.access_time,
                  "Last Update",
                  _formatTime(_lastUpdate!),
                ),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Waiting for location...",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Make sure location is enabled",
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTracking ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: _isTracking
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_fill_outlined,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _isTracking ? "STOP LIVE TRACKING" : "START LIVE TRACKING",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return "$minutes minute${minutes > 1 ? 's' : ''} ago";
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return "$hours hour${hours > 1 ? 's' : ''} ago";
    } else {
      final days = difference.inDays;
      return "$days day${days > 1 ? 's' : ''} ago";
    }
  }
}
