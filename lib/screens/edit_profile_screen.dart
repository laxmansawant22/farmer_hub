import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    String user = "admin"; // Using the same key as registration
    setState(() {
      _nameController.text = prefs.getString('name_$user') ?? "";
      _phoneController.text = prefs.getString('phone_$user') ?? "";
      _addressController.text = prefs.getString('address_$user') ?? "";
      _postController.text = prefs.getString('post_$user') ?? "";
    });
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      String user = "admin";

      await prefs.setString('name_$user', _nameController.text.trim());
      await prefs.setString('phone_$user', _phoneController.text.trim());
      await prefs.setString('address_$user', _addressController.text.trim());
      await prefs.setString('post_$user', _postController.text.trim());

      if (!mounted) return; // Fix for async gaps
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green)
      );
      Navigator.pop(context, true); // Return 'true' to refresh the profile screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF4A6D41),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildEditField(_nameController, "Full Name", Icons.person),
              _buildPhoneField(),
              _buildEditField(_addressController, "Address", Icons.agriculture),
              _buildEditField(_postController, "Post Office", Icons.local_post_office),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6D41),
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF4A6D41)),
          border: const OutlineInputBorder(),
        ),
        validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
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
        decoration: const InputDecoration(
          labelText: "Mobile Number",
          prefixIcon: Icon(Icons.phone, color: Color(0xFF4A6D41)),
          border: OutlineInputBorder(),
        ),
        validator: (value) => (value == null || value.length != 10) ? "Enter 10 digits" : null,
      ),
    );
  }
}