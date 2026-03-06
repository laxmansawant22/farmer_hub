import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, String> details = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllDetails();
  }

  Future<void> _loadAllDetails() async {
    final prefs = await SharedPreferences.getInstance();
    // Using 'admin' as the key to match your registration logic
    String user = "admin";

    setState(() {
      details = {
        'name': prefs.getString('name_$user') ?? "Not Set",
        'phone': prefs.getString('phone_$user') ?? "Not Set",
        'email': prefs.getString('email_$user') ?? "Not Provided",
        'username': user,
        'address': prefs.getString('address_$user') ?? "Not Set",
        'post': prefs.getString('post_$user') ?? "Not Set",
        'selfie': prefs.getString('selfie_$user') ?? "",
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: const Text("My Detailed Profile", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🤳 Fixed Selfie Display with Border
            Center(
              child: CircleAvatar(
                radius: 72,
                backgroundColor: const Color(0xFF4A6D41), // Acts as border color
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: (details['selfie'] != null && details['selfie'] != "")
                      ? FileImage(File(details['selfie']!))
                      : null,
                  child: (details['selfie'] == null || details['selfie'] == "")
                      ? const Icon(Icons.person, size: 70)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 30),

            _buildDetailCard("Full Name", details['name']!, Icons.person),
            _buildDetailCard("Mobile Number", details['phone']!, Icons.phone),
            _buildDetailCard("Gmail", details['email']!, Icons.email),
            _buildDetailCard("Username", details['username']!, Icons.alternate_email),
            _buildDetailCard("Farm Address", details['address']!, Icons.agriculture),
            _buildDetailCard("Post Office", details['post']!, Icons.local_post_office),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // Updated from .withOpacity to .withValues to fix deprecation
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A6D41)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}