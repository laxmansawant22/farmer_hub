import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // 📍 REQUIRED: For base64 decoding
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';

class ProfileScreen extends StatefulWidget {
  final String role; // 'farmer', 'store', or 'customer'
  const ProfileScreen({super.key, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  final List<File> _farmPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Get current user email for Firestore
  final String? userEmail = FirebaseAuth.instance.currentUser?.email;

  Future<void> _pickImage(bool isProfile, {bool fromCamera = false}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(pickedFile.path);
        } else {
          _farmPhotos.add(File(pickedFile.path));
        }
      });
      // Note: You would typically upload this to Firestore here
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📍 Dynamic Theme Color based on role
    final Color themeColor = widget.role == 'farmer'
        ? const Color(0xFF4A6D41)
        : widget.role == 'store'
        ? Colors.blue.shade800
        : Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate(context, 'my_profile')),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userEmail).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Fallback values
          String name = "No Name Found";
          String phone = "No Phone Number";
          String address = "No Address Provided";
          String imageUrlBase64 = "";
          String farmType = "Not Specified";
          String farmSize = "Not Specified";
          String storeName = "Not Specified";

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? name;
            phone = data['phone'] ?? phone;
            address = data['address'] ?? address;
            imageUrlBase64 = data['imageUrl'] ?? "";
            farmType = data['farmType'] ?? farmType;
            farmSize = data['farmSize'] ?? farmSize;
            storeName = data['storeName'] ?? storeName;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // PROFILE IMAGE SECTION
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (imageUrlBase64.isNotEmpty
                            ? MemoryImage(base64Decode(imageUrlBase64))
                            : null),
                        child: (_profileImage == null && imageUrlBase64.isEmpty)
                            ? Icon(Icons.person, size: 60, color: themeColor)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: themeColor,
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            onPressed: () => _showPickerOptions(true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(userEmail ?? "", style: const TextStyle(color: Colors.grey)),

                const SizedBox(height: 30),
                const Divider(),

                // COMMON USER DETAILS
                _buildInfoTile(Icons.phone, "Phone Number", phone, themeColor),
                _buildInfoTile(Icons.location_on, "Address", address, themeColor),
                _buildInfoTile(Icons.badge, "Role", widget.role.toUpperCase(), themeColor),

                // 📍 FARMER SPECIFIC SECTION
                if (widget.role == 'farmer') ...[
                  const Divider(),
                  _buildSectionHeader("Farm Details", themeColor),
                  _buildInfoTile(Icons.agriculture, "Farm Type", farmType, themeColor),
                  _buildInfoTile(Icons.straighten, "Farm Size", farmSize, themeColor),
                ],

                // 📍 STORE SPECIFIC SECTION
                if (widget.role == 'store') ...[
                  const Divider(),
                  _buildSectionHeader("Store Details", themeColor),
                  _buildInfoTile(Icons.storefront, "Store Name", storeName, themeColor),
                ],

                const SizedBox(height: 30),

                // 📍 PHOTOS SECTION (Hidden for Customers)
                if (widget.role == 'farmer' || widget.role == 'store') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          widget.role == 'farmer' ? "Farm Photos" : "Store Photos",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      TextButton.icon(
                        onPressed: () => _showPickerOptions(false),
                        icon: const Icon(Icons.add_a_photo),
                        label: Text(AppTranslations.translate(context, 'add_small')),
                        style: TextButton.styleFrom(foregroundColor: themeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _farmPhotos.isEmpty ? _buildEmptyState() : _buildPhotoGrid(),
                ],

                const SizedBox(height: 20),

                // LOGOUT BUTTON
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text("Logout", style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _farmPhotos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(_farmPhotos[index], fit: BoxFit.cover),
        );
      },
    );
  }

  void _showPickerOptions(bool isProfile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppTranslations.translate(context, 'gallery')),
              onTap: () {
                _pickImage(isProfile, fromCamera: false);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppTranslations.translate(context, 'camera')),
              onTap: () {
                _pickImage(isProfile, fromCamera: true);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: const Center(
          child: Text(
              "No photos uploaded yet",
              style: TextStyle(color: Colors.grey)
          )
      ),
    );
  }
}