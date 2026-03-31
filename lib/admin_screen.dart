import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String userId = snapshot.data!.docs[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['role'] == 'Farmer' ? Colors.green : Colors.blue,
                    child: Text(user['name']?[0].toUpperCase() ?? "U", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user['name'] ?? "Unknown"),
                  subtitle: Text("${user['role']} | ${user['email']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDetailScreen(userData: user, userId: userId),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class UserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const UserDetailScreen({super.key, required this.userData, required this.userId});

  // 📧 Function to send Email via Gmail
  void _sendEmail(String email, String subject, String body) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  // 🚫 Show Blocking Dialog
  void _showBlockDialog(BuildContext context) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block & Notify User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Provide a reason for blocking this user. This will be sent to their email."),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: "Reason for blocking...", border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // 1. Update Firestore Status (Optional: Add a 'status' field to user)
              await FirebaseFirestore.instance.collection('users').doc(userId).update({'status': 'Blocked'});
              
              // 2. Open Gmail with the reason
              _sendEmail(
                userData['email'], 
                "Account Blocked - Admin Alert", 
                "Hello ${userData['name']},\n\nYour account has been blocked for the following reason:\n${reasonController.text}\n\nPlease contact support for more details."
              );
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User blocked and email drafted.")));
            },
            child: const Text("Block User", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(userData['name'] ?? "Details"),
          actions: [
            IconButton(
              icon: const Icon(Icons.block, color: Colors.red),
              onPressed: () => _showBlockDialog(context),
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Issues", icon: Icon(Icons.report_problem)),
              Tab(text: "Orders", icon: Icon(Icons.shopping_bag)),
              Tab(text: "Products", icon: Icon(Icons.inventory)),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Email: ${userData['email']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Phone: ${userData['phone'] ?? 'N/A'}"),
                  Text("Address: ${userData['address'] ?? 'N/A'}"),
                  Text("Role: ${userData['role']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildList('order_issues', 'customerId', "No issues reported."),
                  _buildList('orders', 'customerId', "No orders found."),
                  _buildList('products', 'farmerId', "No products added."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String collection, String filterField, String emptyMsg) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).where(filterField, isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(collection == 'products' ? data['name'] : "ID: ${snapshot.data!.docs[index].id.substring(0, 8)}"),
                subtitle: Text(collection == 'order_issues' ? "Issue: ${data['issue']}" : "Status: ${data['status'] ?? 'N/A'}"),
                trailing: Text(collection == 'products' ? "Rs ${data['price']}" : ""),
              ),
            );
          },
        );
      },
    );
  }
}