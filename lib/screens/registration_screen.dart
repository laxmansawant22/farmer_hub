import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart' show CameraDevice, ImagePicker, ImageSource, XFile;
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationScreen extends StatefulWidget {
  final bool isFarmer;
  const RegistrationScreen({super.key, required this.isFarmer});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isObscured = true;
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _addressController = TextEditingController();
  final _postOfficeController = TextEditingController();

  Future<void> _takeSelfie() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (photo != null) {
      setState(() => _selfieImage = File(photo.path));
    }
  }

  // 📍 Save data to Shared Preferences
  Future<void> _submitRegistration() async {
    if (_selfieImage == null) {
      _showMsg("Please take a selfie*", Colors.red);
      return;
    }

    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      String username = _userController.text.trim();

      // Store password and role keyed by username
      await prefs.setString('pass_$username', _passController.text);
      await prefs.setBool('isFarmer_$username', widget.isFarmer);
      await prefs.setString('name_$username', _nameController.text.trim());
      // Optional: Save selfie path
      await prefs.setString('selfie_$username', _selfieImage!.path);

      _showMsg("Registration Successful!", Colors.green);
      Navigator.pop(context);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: Text("Register as ${widget.isFarmer ? 'Farmer' : 'Customer'}", style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _takeSelfie,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _selfieImage != null ? FileImage(_selfieImage!) : null,
                  child: _selfieImage == null ? const Icon(Icons.camera_alt, color: Color(0xFF4A6D41)) : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildField(_nameController, "Full Name*", Icons.person, true),
              _buildPhoneField(),
              _buildField(_emailController, "Gmail (Optional)", Icons.email, false),
              _buildField(_userController, "Create Username*", Icons.alternate_email, true),
              _buildPasswordField(),
              _buildField(_addressController, widget.isFarmer ? "Farm Address*" : "Home Address*", widget.isFarmer ? Icons.agriculture : Icons.home, true),
              _buildField(_postOfficeController, "Post Office Address*", Icons.local_post_office, true),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitRegistration,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), minimumSize: const Size(double.infinity, 55)),
                child: const Text("Register", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: "Mobile Number (10 digits)*", prefixIcon: const Icon(Icons.phone, color: Color(0xFF4A6D41)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        validator: (value) => (value == null || value.length != 10) ? "Enter 10 digit number" : null,
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, bool req) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: hint, prefixIcon: Icon(icon, color: const Color(0xFF4A6D41)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        validator: (value) => (req && (value == null || value.trim().isEmpty)) ? "Compulsory field" : null,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _passController,
        obscureText: _isObscured,
        decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: "Create Password*", prefixIcon: const Icon(Icons.lock, color: Color(0xFF4A6D41)), suffixIcon: IconButton(icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isObscured = !_isObscured)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        validator: (value) => (value == null || value.length < 6) ? "Min 6 characters" : null,
      ),
    );
  }
}