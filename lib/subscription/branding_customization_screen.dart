import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'payment_screen.dart';

class BrandingCustomizationScreen extends StatefulWidget {
  final Map<String, dynamic> selectedPlan;
  final bool isYearly;

  const BrandingCustomizationScreen({
    super.key,
    required this.selectedPlan,
    required this.isYearly,
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
  File? _logoFile;
  bool _useDarkMode = false;
  String _selectedFont = 'Roboto';

  final ImagePicker _picker = ImagePicker();

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

  void _showColorPicker(bool isPrimary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPrimary ? 'Pick Primary Color' : 'Pick Secondary Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: isPrimary ? _primaryColor : _secondaryColor,
            onColorChanged: (color) {
              setState(() {
                if (isPrimary) {
                  _primaryColor = color;
                } else {
                  _secondaryColor = color;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Branding'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
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
          'Brand Colors',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildColorPreviewCube(
                'Primary Color',
                _primaryColor,
                () => _showColorPicker(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildColorPreviewCube(
                'Secondary Color',
                _secondaryColor,
                () => _showColorPicker(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPreviewCube(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
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
              // Dark Mode Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dark_mode_outlined,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Default to Dark Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _useDarkMode,
                    onChanged: (val) {
                      setState(() {
                        _useDarkMode = val;
                      });
                    },
                    activeColor: _primaryColor,
                  ),
                ],
              ),
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
                    items: ['Roboto', 'Open Sans', 'Lato', 'Montserrat']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
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
              color: _useDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                    color: _useDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.white,
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
                            'Your Logo',
                            style: TextStyle(
                              color: _useDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
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
                                Container(
                                  width: 100,
                                  height: 10,
                                  color: _useDarkMode
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 60,
                                  height: 10,
                                  color: _useDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
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
                    color: _useDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.white,
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

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // Prepare branding data
          final brandingData = {
            'primaryColor': _primaryColor.value,
            'secondaryColor': _secondaryColor.value,
            'logoPath': _logoFile?.path,
            'useDarkMode': _useDarkMode,
            'fontFamily': _selectedFont,
          };

          // Navigate to Payment
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                planName: widget.selectedPlan['name'],
                isYearly: widget.isYearly,
                price: widget.isYearly
                    ? widget.selectedPlan['yearlyPrice']
                    : widget.selectedPlan['monthlyPrice'],
                originalPrice: widget.isYearly
                    ? widget.selectedPlan['originalYearlyPrice']
                    : null,
                brandingData: brandingData,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Continue to Payment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
