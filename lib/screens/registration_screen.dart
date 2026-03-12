import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../translations.dart';

class RegistrationScreen extends StatefulWidget {
  final String role;
  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _image;
  String? _base64Image;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _postOfficeController = TextEditingController();
  final _otherFarmTypeController = TextEditingController();

  String _selectedFarmType = 'Pure Organic';
  bool _showOtherField = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Gallery'),
              onTap: () => _processImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              onTap: () => _processImage(ImageSource.camera),
            ),
            if (_image != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _image = null;
                    _base64Image = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(ImageSource source) async {
    Navigator.pop(context);
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 20,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _image = File(pickedFile.path);
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _getLiveLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Location services are disabled.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Captured!")));
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.translate(context, 'photo_required'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String email = _emailController.text.trim().isEmpty
          ? "${_usernameController.text.trim()}@krishimarket.com"
          : _emailController.text.trim();
      String password = _passwordController.text.trim();

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'phone': _mobileController.text.trim(),
        'email': email,
        'username': _usernameController.text.trim(),
        'role': widget.role,
        'address': _addressController.text.trim(),
        'postOffice': _postOfficeController.text.trim(),
        'imageUrl': _base64Image,
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.role == 'farmer') {
        userData['farmType'] = _showOtherField ? _otherFarmTypeController.text.trim() : _selectedFarmType;
      }

      await FirebaseFirestore.instance.collection('users').doc(email).set(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);

      if (!mounted) return;

      // 📍 ROLE CONTINUITY: This passes the current role to the login screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
        arguments: widget.role,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF4A6D41);
    final Color themeColor = widget.role == 'farmer' ? primaryGreen
        : widget.role == 'store' ? Colors.blue.shade800 : Colors.orange.shade800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${AppTranslations.translate(context, 'register')} (${AppTranslations.translate(context, widget.role)})",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 55, backgroundColor: Colors.grey.shade200,
                      backgroundImage: _image != null ? FileImage(_image!) : null,
                      child: _image == null ? Icon(Icons.camera_alt, color: themeColor, size: 35) : null,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildField(_nameController, AppTranslations.translate(context, 'full name'), Icons.person, themeColor),

                  _buildField(_mobileController, AppTranslations.translate(context, 'mobile number'), Icons.phone, themeColor,
                    isNumber: true,
                    limit: 10,
                    validator: (val) => (val == null || val.length != 10) ? "Enter exactly 10 digits" : null,
                  ),

                  _buildField(_emailController, AppTranslations.translate(context, 'email'), Icons.email, themeColor, isRequired: false),

                  if (widget.role == 'farmer') ...[
                    _buildFarmTypeDropdown(themeColor),
                    if (_showOtherField)
                      _buildField(_otherFarmTypeController, "Specify Farm Type", Icons.edit_note, themeColor),
                  ],

                  _buildField(_passwordController, AppTranslations.translate(context, 'password'), Icons.lock, themeColor, isPassword: true),
                  _buildField(_addressController, AppTranslations.translate(context, 'address'), Icons.location_on, themeColor),

                  _buildLocationTile(themeColor),

                  _buildField(_postOfficeController, AppTranslations.translate(context, 'post office'), Icons.local_post_office, themeColor),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor, minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, Color color,
      {bool isPassword = false, bool isRequired = true, bool isNumber = false, int? limit, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: (isPassword && _obscurePassword),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: limit != null ? [LengthLimitingTextInputFormatter(limit), FilteringTextInputFormatter.digitsOnly] : [],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        validator: validator ?? (value) => (isRequired && (value == null || value.isEmpty)) ? "Required" : null,
        decoration: InputDecoration(
          hintText: hint, prefixIcon: Icon(icon, color: color),
          filled: true, fillColor: const Color(0xFFF8F8F8),
          suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _buildFarmTypeDropdown(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: _selectedFarmType,
        decoration: InputDecoration(prefixIcon: Icon(Icons.agriculture, color: themeColor), filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        items: ['Pure Organic', 'Fertilizer Based', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() { _selectedFarmType = v!; _showOtherField = (v == 'Other'); }),
      ),
    );
  }

  Widget _buildLocationTile(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: ListTile(
          leading: Icon(Icons.gps_fixed, color: themeColor),
          title: Text(widget.role == 'farmer' ? "Capture Farm Location" : "Capture Live Location",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(_latitude == null ? "Not Captured" : "Successful: ${_latitude!.toStringAsFixed(2)}, ${_longitude!.toStringAsFixed(2)}"),
          trailing: _isFetchingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.add_location_alt), onPressed: _getLiveLocation),
        ),
      ),
    );
  }
}