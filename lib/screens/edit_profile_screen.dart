import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../translations.dart';

class EditProfileScreen extends StatefulWidget {
  final String role;
  const EditProfileScreen({super.key, required this.role});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postController = TextEditingController();
  final _otherFarmTypeController = TextEditingController();

  // Photo Logic
  File? _selectedImageFile;
  String _currentImageUrlBase64 = "";
  final ImagePicker _picker = ImagePicker();

  // Farm Type Logic
  String _selectedFarmType = 'Pure Organic';
  bool _showOtherField = true;

  // Location Logic
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadFirebaseUserData();
  }

  Color get themeColor {
    if (widget.role == 'farmer') return const Color(0xFF4A6D41);
    if (widget.role == 'store') return Colors.blue.shade800;
    if (widget.role == 'customer') return Colors.teal;
    return Colors.orange.shade800;
  }

  Future<void> _loadFirebaseUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _addressController.text = data['address'] ?? "";
        _postController.text = data['postOffice'] ?? "";
        _latitude = data['latitude'];
        _longitude = data['longitude'];
        _currentImageUrlBase64 = data['imageUrl'] ?? "";

        if (widget.role == 'farmer') {
          String savedType = data['farmType'] ?? 'Pure Organic';
          if (['Pure Organic', 'Fertilizer Based'].contains(savedType)) {
            _selectedFarmType = savedType;
            _showOtherField = false;
          } else {
            _selectedFarmType = 'Other';
            _showOtherField = true;
            _otherFarmTypeController.text = savedType;
          }
        }

        _isLoadingData = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Updated!")));
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _showSaveConfirmation() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Changes?"),
        content: const Text("Confirm to update your profile information."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> updateData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'postOffice': _postController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    if (widget.role == 'farmer') {
      updateData['farmType'] = _showOtherField ? _otherFarmTypeController.text.trim() : _selectedFarmType;
    }

    if (_selectedImageFile != null) {
      List<int> imageBytes = await _selectedImageFile!.readAsBytes();
      updateData['imageUrl'] = base64Encode(imageBytes);
    }

    await FirebaseFirestore.instance.collection('users').doc(user.email).update(updateData);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate(context, 'profile_updated')), backgroundColor: Colors.green)
    );
    Navigator.pop(context, true);
  }

  // 📍 Double Confirmation Logic for Account Deletion
  Future<void> _confirmDeleteAccount() async {
    // FIRST POP-UP: Email warning
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("IMPORTANT: After deleting this account, you will NOT be able to use this same Email ID to create a new account in the future. Do you still want to proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No, Keep Account")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteWarning(); // Trigger second pop-up
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("I Understand, Proceed", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 📍 SECOND POP-UP: Final verification
  Future<void> _showFinalDeleteWarning() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Final Warning", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This action is permanent and all your data will be wiped from our servers. Are you 100% sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _deleteAccountExecution();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes, Delete Forever", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountExecution() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.email).delete();
      await user.delete();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("For security, please logout and log back in before deleting your account.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate(context, 'edit_profile')),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _selectedImageFile != null
                          ? FileImage(_selectedImageFile!)
                          : (_currentImageUrlBase64.isNotEmpty
                          ? MemoryImage(base64Decode(_currentImageUrlBase64))
                          : null),
                      child: (_selectedImageFile == null && _currentImageUrlBase64.isEmpty)
                          ? Icon(Icons.person, size: 50, color: themeColor)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: CircleAvatar(
                          backgroundColor: themeColor,
                          radius: 18,
                          child: const Icon(Icons.edit, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              _buildEditField(_nameController, 'full_name', Icons.person),
              _buildPhoneField(),

              if (widget.role == 'farmer') ...[
                const Text("Farm Type", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedFarmType,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.agriculture, color: themeColor),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['Pure Organic', 'Fertilizer Based', 'Other']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFarmType = value!;
                      _showOtherField = (value == 'Other');
                    });
                  },
                ),
                const SizedBox(height: 15),
                if (_showOtherField)
                  _buildEditField(_otherFarmTypeController, 'Specify Farm Type', Icons.edit_note),
              ],

              _buildEditField(_addressController, 'address', Icons.location_on),
              _buildEditField(_postController, 'post_office', Icons.local_post_office),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: themeColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_latitude == null
                          ? "Location not set"
                          : "Lat: ${_latitude!.toStringAsFixed(4)}, Long: ${_longitude!.toStringAsFixed(4)}"),
                    ),
                    _isFetchingLocation
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(onPressed: _updateLocation, child: const Text("Update GPS")),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _showSaveConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    AppTranslations.translate(context, 'save_changes'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),

              const SizedBox(height: 15),

              TextButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String translationKey, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: AppTranslations.translate(context, translationKey),
          prefixIcon: Icon(icon, color: themeColor),
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor, width: 2)),
        ),
        validator: (value) => (value == null || value.isEmpty) ? AppTranslations.translate(context, 'err_required') : null,
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
        decoration: InputDecoration(
          labelText: AppTranslations.translate(context, 'mobile_number'),
          prefixIcon: Icon(Icons.phone, color: themeColor),
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor, width: 2)),
        ),
        validator: (value) => (value == null || value.length != 10) ? AppTranslations.translate(context, 'err_phone_digits') : null,
      ),
    );
  }
}