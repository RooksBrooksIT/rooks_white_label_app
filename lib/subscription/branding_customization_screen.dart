import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_dashboard.dart';
import 'package:subscription_rooks_app/services/auth_state_service.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/storage_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandingCustomizationScreen extends StatefulWidget {
  final String? planName;
  final bool? isYearly;
  final int? price;
  final int? originalPrice;
  final String? paymentMethod;
  final String? transactionId;
  final bool isEditMode;

  const BrandingCustomizationScreen({
    super.key,
    this.planName,
    this.isYearly,
    this.price,
    this.originalPrice,
    this.paymentMethod,
    this.transactionId,
    this.isEditMode = false,
  });

  @override
  State<BrandingCustomizationScreen> createState() =>
      _BrandingCustomizationScreenState();
}

class _BrandingCustomizationScreenState
    extends State<BrandingCustomizationScreen> {
  // Branding State
  Color _primaryColor = Colors.deepPurple;
  Color _secondaryColor = Colors.amber;
  Color _backgroundColor = Colors.white; // Fixed to white as per requirements
  File? _logoFile;
  String? _existingLogoUrl;
  final bool _useDarkMode = false; // Fixed to false as per requirements

  String _selectedFont = 'Roboto';
  final TextEditingController _appNameController = TextEditingController(
    text: 'My Awesome App',
  );

  // Preset Themes
  final List<Map<String, Color>> _presetThemes = [
    // Row 1
    {
      'primary': const Color(0xFF0D47A1),
      'secondary': const Color(0xFF90CAF9),
    }, // Blue
    {
      'primary': const Color(0xFF424242),
      'secondary': const Color(0xFF90CAF9),
    }, // Grey/Blue
    {
      'primary': const Color(0xFF1565C0),
      'secondary': const Color(0xFF78909C),
    }, // Navy/BlueGrey
    {
      'primary': const Color(0xFF37474F),
      'secondary': const Color(0xFFB0BEC5),
    }, // DarkBlueGrey
    {
      'primary': const Color(0xFF263238),
      'secondary': const Color(0xFFB2DFDB),
    }, // TealGrey
    {
      'primary': const Color(0xFF00695C),
      'secondary': const Color(0xFF80CBC4),
    }, // Teal
    // Row 2
    {
      'primary': const Color(0xFF1B5E20),
      'secondary': const Color(0xFFA5D6A7),
    }, // Forest
    {
      'primary': const Color(0xFF33691E),
      'secondary': const Color(0xFFC5E1A5),
    }, // Olive
    {
      'primary': const Color(0xFF827717),
      'secondary': const Color(0xFFE6EE9C),
    }, // Gold
    {
      'primary': const Color(0xFFE65100),
      'secondary': const Color(0xFFFFCC80),
    }, // Orange
    {
      'primary': const Color(0xFF5D4037),
      'secondary': const Color(0xFFD7CCC8),
    }, // Brown
    {
      'primary': const Color(0xFF880E4F),
      'secondary': const Color(0xFFF48FB1),
    }, // Maroon
    // Row 3
    {
      'primary': const Color(0xFF4E342E),
      'secondary': const Color(0xFFD7CCC8),
    }, // Coffee
    {
      'primary': const Color(0xFF880E4F),
      'secondary': const Color(0xFFF06292),
    }, // Magenta
    {
      'primary': const Color(0xFF4A148C),
      'secondary': const Color(0xFFCE93D8),
    }, // Purple
  ];

  int _selectedThemeIndex = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize with current values from ThemeService
    final theme = ThemeService.instance;
    _primaryColor = theme.primaryColor;
    _secondaryColor = theme.secondaryColor;
    _backgroundColor = Colors.white; // Requirement: Fixed to white
    _selectedFont = theme.fontFamily;
    _appNameController.text = theme.appName;

    // Pre-fill existing logo URL in edit mode
    if (widget.isEditMode && theme.logoUrl != null) {
      _existingLogoUrl = theme.logoUrl;
    }

    // Try to find if current colors match a preset
    _selectedThemeIndex = _presetThemes.length; // Default to Custom
    for (int i = 0; i < _presetThemes.length; i++) {
      if (_presetThemes[i]['primary']?.value == _primaryColor.value &&
          _presetThemes[i]['secondary']?.value == _secondaryColor.value) {
        _selectedThemeIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _logoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Handle permission errors, etc.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  void _showColorPicker(String type) {
    Color currentColor;
    if (type == 'primary') {
      currentColor = _primaryColor;
    } else if (type == 'secondary') {
      currentColor = _secondaryColor;
    } else {
      currentColor = _backgroundColor;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick ${type[0].toUpperCase()}${type.substring(1)} Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (type == 'primary') {
                  _primaryColor = color;
                } else if (type == 'secondary') {
                  _secondaryColor = color;
                } else {
                  _backgroundColor = color;
                }

                if (type != 'background') {
                  // When manually picking primary/secondary, set to Custom mode
                  _selectedThemeIndex = _presetThemes.length;
                }
              });
            },
            showLabel: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Got it'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeService.instance.defaultTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.blue.shade50.withOpacity(0.5),
              Colors.grey.shade200,
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Customize Branding'),
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.black,
            elevation: 0,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildAppInfoSection(),
                      const SizedBox(height: 32),
                      _buildLogoUploadSection(),
                      const SizedBox(height: 32),
                      _buildColorThemeSection(),
                      const SizedBox(height: 32),
                      _buildVisualSettingsSection(),
                      const SizedBox(height: 48),
                      _buildPreviewSection(),
                      const SizedBox(height: 48),
                      _buildContinueButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _appNameController,
            decoration: InputDecoration(
              hintText: 'Enter your app name',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.edit_note, color: _primaryColor),
            ),
            onChanged: (value) {
              setState(() {}); // Trigger rebuild for preview
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brand Your App',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Make the app truly yours. Upload your logo and choose your brand colors.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Logo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: _logoFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_logoFile!, fit: BoxFit.contain),
                  )
                : _existingLogoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _existingLogoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: Colors.deepPurple.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to change logo',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: Colors.deepPurple.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to upload logo',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PNG, JPG up to 5MB',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick a theme color',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255), // Dark background
            borderRadius: BorderRadius.circular(16),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // Fits better on mobile width
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _presetThemes.length + 1, // +1 for Custom
            itemBuilder: (context, index) {
              final isCustom = index == _presetThemes.length;
              final isSelected = _selectedThemeIndex == index;

              if (isCustom) {
                return _buildCustomThemeCircle(isSelected);
              }

              return _buildThemeCircle(
                index,
                _presetThemes[index]['primary']!,
                _presetThemes[index]['secondary']!,
                isSelected,
              );
            },
          ),
        ),

        if (_selectedThemeIndex == _presetThemes.length) ...[
          const SizedBox(height: 24),
          const Text(
            'Custom Colors',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildManualColorButton(
                  'Primary',
                  _primaryColor,
                  () => _showColorPicker('primary'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildManualColorButton(
                  'Secondary',
                  _secondaryColor,
                  () => _showColorPicker('secondary'),
                ),
              ),
            ],
          ),
        ],

        // Background Color Selection Removed
      ],
    );
  }

  Widget _buildThemeCircle(
    int index,
    Color primary,
    Color secondary,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedThemeIndex = index;
          _primaryColor = primary;
          _secondaryColor = secondary;
        });
      },
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: ClipOval(
              child: CustomPaint(
                size: const Size(50, 50),
                painter: ThemeCirclePainter(
                  primary: primary,
                  secondary: secondary,
                  tertiary: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomThemeCircle(bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedThemeIndex = _presetThemes.length;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3F51B5),
            ),
          ),
          const Icon(Icons.colorize, color: Colors.white, size: 20),
          if (isSelected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualColorButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visual Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Dark Mode Toggle Removed
              const Divider(height: 32),
              // Font Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.font_download_outlined,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Font Family',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _selectedFont,
                    underline: Container(),
                    items:
                        [
                              'Roboto',
                              'Lato',
                              'Montserrat',
                              'Playfair Display',
                              'Merriweather',
                              'Oswald',
                              'Fira Code',
                              'Dancing Script',
                            ]
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f,
                                  style: GoogleFonts.getFont(f, fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFont = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Preview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 250,
            height: 450,
            decoration: BoxDecoration(
              color: _backgroundColor,

              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade300, width: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Mock App Bar
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: _backgroundColor, // Use selected background color
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      topRight: Radius.circular(17),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _logoFile != null
                        ? Image.file(
                            _logoFile!,
                            height: 30,
                            fit: BoxFit.contain,
                          )
                        : Text(
                            _appNameController.text.isEmpty
                                ? 'Your Logo'
                                : _appNameController.text,
                            style: GoogleFonts.getFont(
                              _selectedFont,
                              color: _backgroundColor.computeLuminance() < 0.5
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _secondaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lorem Ipsum',
                                  style: GoogleFonts.getFont(
                                    _selectedFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _backgroundColor.computeLuminance() <
                                            0.5
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Font Preview Text',
                                  style: GoogleFonts.getFont(
                                    _selectedFont,
                                    fontSize: 10,
                                    color:
                                        _backgroundColor.computeLuminance() <
                                            0.5
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Mock Tab Bar
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(17),
                      bottomRight: Radius.circular(17),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Icon(Icons.home, color: _primaryColor),
                      Icon(Icons.search, color: Colors.grey),
                      Icon(Icons.person, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _generateReferralCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    widget.isEditMode
                        ? 'Updating profile...'
                        : 'Finalizing subscription...',
                  ),
                ],
              ),
            ),
          );

          try {
            // Prepare branding data
            final brandingData = {
              'appName': _appNameController.text,
              'primaryColor': _primaryColor.value,
              'secondaryColor': _secondaryColor.value,
              'backgroundColor': _backgroundColor.value,
              'useDarkMode': _useDarkMode,
              'fontFamily': _selectedFont,
              'databaseName': ThemeService.instance.databaseName,
            };

            // Use real auth uid if available
            final uid =
                AuthStateService.instance.currentUser?.uid ?? 'demo-user';

            print(
              'BrandingCustomizationScreen: uid=$uid, appName=${_appNameController.text}',
            );
            print('BrandingCustomizationScreen: logoFile=${_logoFile?.path}');

            // Upload logo if a new file was picked
            if (_logoFile != null) {
              print('BrandingCustomizationScreen: Starting logo upload...');
              final logoUrl = await StorageService.instance.uploadLogo(
                userId: uid,
                file: _logoFile!,
              );
              if (logoUrl != null) {
                brandingData['logoUrl'] = logoUrl;
              }
            } else if (_existingLogoUrl != null) {
              // Keep existing logo URL if no new file was picked
              brandingData['logoUrl'] = _existingLogoUrl!;
            }

            if (widget.isEditMode) {
              // --- Edit Mode: Only update branding data ---

              // Save to App-Specific Collection
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: _appNameController.text,
                brandingData: brandingData,
              );

              // Also save to default 'data' location
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                brandingData: brandingData,
              );

              // Update App Theme
              ThemeService.instance.updateTheme(
                primary: _primaryColor,
                secondary: _secondaryColor,
                backgroundColor: _backgroundColor,
                isDarkMode: _useDarkMode,
                fontFamily: _selectedFont,
                appName: _appNameController.text,
                databaseName: ThemeService.instance.databaseName,
                logoUrl: brandingData['logoUrl'] as String?,
              );

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // Use pushReplacement to force a full rebuild of the dashboard
              // with the updated branding colors and app name
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const admindashboard()),
              );
            } else {
              // --- First-time Setup Mode ---

              // Generate Referral Code
              final referralCode = _generateReferralCode();
              brandingData['referralCode'] = referralCode;

              // 1. Save to App-Specific Collection
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: _appNameController.text,
                brandingData: brandingData,
              );

              // Also save to default 'data' location for simplified lookups during login
              await FirestoreService.instance.saveAppBranding(
                tenantId: ThemeService.instance.databaseName,
                appId: 'data',
                brandingData: brandingData,
              );

              // 2. Save Referral Code Mapping
              await FirestoreService.instance.saveReferralCode(
                code: referralCode,
                tenantId: ThemeService.instance.databaseName,
                appId: _appNameController.text,
                adminUid: uid,
              );

              // 3. Save Full Subscription with Branding (linked to user)
              await FirestoreService.instance.upsertSubscription(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                appId: _appNameController.text,
                planName: widget.planName!,
                isYearly: widget.isYearly!,
                price: widget.price!,
                originalPrice: widget.originalPrice,
                paymentMethod: widget.paymentMethod!,
                brandingData: brandingData,
              );

              // 4. Update Global User Directory (Link Admin to this App)
              await FirestoreService.instance.saveUserDirectory(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                role: 'admin',
                appName: _appNameController.text,
              );

              // 5. Activate the user after successful subscription
              await FirestoreService.instance.setUserActiveStatus(
                uid: uid,
                tenantId: ThemeService.instance.databaseName,
                active: true,
              );

              // Update App Theme
              ThemeService.instance.updateTheme(
                primary: _primaryColor,
                secondary: _secondaryColor,
                backgroundColor: _backgroundColor,
                isDarkMode: _useDarkMode,
                fontFamily: _selectedFont,
                appName: _appNameController.text,
                databaseName: ThemeService.instance.databaseName,
                logoUrl: brandingData['logoUrl'] as String?,
              );

              if (!mounted) return;
              Navigator.pop(context); // Close loading

              // Show Success Dialog with Referral Code
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Setup Complete!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your application is ready. Share this referral code with your customers so they can register:',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          referralCode,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'You can verify this later in your dashboard.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Let\'s Go'),
                    ),
                  ],
                ),
              );

              if (!mounted) return;
              // Navigate directly to Admin Dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const admindashboard()),
                (route) => false,
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving preferences: $e')),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          widget.isEditMode ? 'Update Profile' : 'Complete Setup',
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

class ThemeCirclePainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color tertiary;

  ThemeCirclePainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Draw Top Half (Primary)
    paint.color = primary;
    canvas.drawArc(rect, -3.14159, 3.14159, true, paint);

    // 2. Draw Bottom Left (Secondary)
    paint.color = secondary;
    canvas.drawArc(
      rect,
      1.5708,
      1.5708,
      true,
      paint,
    ); // 90 to 180 degrees ? Wait.
    // Arc starts from positive X axis (0).
    // Top half is -PI to 0. (from left to right top)
    // Actually, drawArc(rect, startAngle, sweepAngle, useCenter, paint)
    // -PI is 180 deg (left). sweep PI (180). This draws Top Half. Correct.

    // Bottom Left:
    // Angle from PI (180 or -180) to PI/2 (90).
    // Let's use 0 to PI (bottom half).
    // Bottom Left is 90 deg to 180 deg?
    // 0 is Right. PI/2 is Bottom. PI is Left.
    // So Bottom Left is from PI/2 to PI.
    // Bottom Right is from 0 to PI/2.

    // Bottom Left Implementation:
    paint.color = secondary;
    canvas.drawArc(rect, 1.5708, 1.5708, true, paint); // PI/2 to PI?
    // sweep 1.57 is 90 deg. Start at 1.57 (90 deg). YES.

    // 3. Draw Bottom Right (Tertiary/Grey)
    paint.color = tertiary;
    canvas.drawArc(rect, 0, 1.5708, true, paint); // 0 to 90 deg.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
