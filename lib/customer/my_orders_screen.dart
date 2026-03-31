import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  void _makeCall(String? phoneNumber, BuildContext context) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch dialer")),
      );
    }
  }

  // 📍 1. Generate Detailed Invoice PDF
  Future<void> _generateInvoice(Map<String, dynamic> order, String docId) async {
    final pdf = pw.Document();
    final date = order['timestamp'] != null ? (order['timestamp'] as Timestamp).toDate() : DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("SOLD BY (Seller):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(order['farmerName'] ?? 'Verified Seller'),
                      pw.Text("Phone: ${order['farmerPhone'] ?? 'N/A'}"),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("BILL TO (Customer):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(order['customerName'] ?? 'Customer'),
                      pw.Text("Phone: ${order['customerPhone'] ?? 'N/A'}"),
                      pw.Container(width: 150, child: pw.Text("Addr: ${order['deliveryAddress'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Order ID: #$docId"),
                pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(date)}"),
              ],
            ),
            pw.SizedBox(height: 15),

            pw.TableHelper.fromTextArray(
              headers: ['Product', 'Price', 'Qty', 'Total'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: (order['items'] as List).map((item) => [
                item['name'],
                "Rs ${item['price']}",
                "${item['cartQty']}",
                "Rs ${(item['price'] * item['cartQty']).toStringAsFixed(2)}"
              ]).toList(),
            ),
            
            pw.SizedBox(height: 20),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Subtotal: Rs ${order['subtotal']}"),
                  pw.Text("Delivery Charges: Rs ${order['deliveryCharges']}"),
                  pw.Container(width: 100, child: pw.Divider()),
                  pw.Text("Total Amount: Rs ${order['totalAmount']}", 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _viewSellerProfile(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Seller Information"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF4A6D41),
              child: Icon(Icons.storefront, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(order['farmerName'] ?? "Farmer", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: Text(order['farmerPhone'] ?? "N/A", style: const TextStyle(color: Colors.black)),
              dense: true,
              onTap: () => _makeCall(order['farmerPhone'], context),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  // 📍 2. Report Issue Logic
  void _showReportIssueSheet(BuildContext context, String orderId) {
    final TextEditingController reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Report an Issue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("What went wrong with your order?", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "e.g., Damaged items, missing quantity...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('order_issues').add({
                  'orderId': orderId,
                  'customerId': FirebaseAuth.instance.currentUser?.uid,
                  'issue': reasonController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'Pending',
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue reported. We will look into it.")));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 45)),
              child: const Text("Submit Report", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track My Orders"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No orders found."));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var orderData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String docId = snapshot.data!.docs[index].id;
              return _buildOrderCard(context, orderData, docId);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, String docId) {
    String status = order['status'] ?? "Requested";
    List items = order['items'] as List? ?? [];
    String productNames = items.map((i) => i['name']).join(", ");

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(productNames, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID: #${docId.substring(0, 8)}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(order['timestamp'] != null 
                    ? DateFormat('dd MMM, hh:mm a').format((order['timestamp'] as Timestamp).toDate()) 
                    : "Just now"),
              ],
            ),
            trailing: _statusChip(status),
          ),
          
          const Divider(height: 0),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _viewSellerProfile(context, order),
                  icon: const Icon(Icons.person_pin, size: 20, color: Colors.black87),
                  label: const Text("View Seller", style: TextStyle(color: Colors.black87)),
                ),
                TextButton.icon(
                  onPressed: () => _generateInvoice(order, docId),
                  icon: const Icon(Icons.file_download, size: 20, color: Colors.black87),
                  label: const Text("Invoice", style: TextStyle(color: Colors.black87)),
                ),
                // 📍 New Report Issue Button for Delivered Orders
                if (status == 'Delivered')
                  TextButton.icon(
                    onPressed: () => _showReportIssueSheet(context, docId),
                    icon: const Icon(Icons.report_problem, size: 20, color: Colors.red),
                    label: const Text("Issue", style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),

          const Divider(height: 0),

          if (status == 'Delivered') _RatingManager(order: order, orderId: docId),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                if (status != 'Delivered' && status != 'Rejected')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makeCall(order['farmerPhone'], context),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text("Call Farmer"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87),
                    ),
                  ),
                if (status == 'Shipping') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmOrderReceived(context, docId),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text("Confirm Received", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrderReceived(BuildContext context, String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Delivered'});
  }

  Widget _statusChip(String status) {
    Color color = status == 'Delivered' ? Colors.green : (status == 'Rejected' ? Colors.red : Colors.blue);
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// 📍 Rating Component (Same as your logic)
class _RatingManager extends StatelessWidget {
  final Map<String, dynamic> order;
  final String orderId;
  const _RatingManager({required this.order, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('orderId', isEqualTo: orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                 showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => _RatingSheet(order: order, orderId: orderId),
                );
              },
              icon: const Icon(Icons.star, color: Colors.white),
              label: const Text("Rate Products", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          );
        }

        var review = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.orange.withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Feedback:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
              Row(children: List.generate(5, (i) => Icon(i < (review['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.orange, size: 16))),
              Text("\"${review['review']}\"", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.black87)),
            ],
          ),
        );
      },
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;
  const _RatingSheet({required this.order, required this.orderId});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 5;
  final _reviewController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Rate Your Experience", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 40),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          TextField(controller: _reviewController, decoration: const InputDecoration(hintText: "Excellent quality...", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('reviews').add({
                'orderId': widget.orderId,
                'rating': _rating,
                'review': _reviewController.text,
                'customerName': FirebaseAuth.instance.currentUser?.displayName ?? "User",
                'timestamp': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), minimumSize: const Size(double.infinity, 45)),
            child: const Text("Submit Review", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}