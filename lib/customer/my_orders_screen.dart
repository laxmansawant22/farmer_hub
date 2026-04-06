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

  // 📍 1. Fixed Call Logic (Using toString() to prevent type errors)
  void _makeCall(String? phoneNumber, BuildContext context) async {
    if (phoneNumber == null || phoneNumber.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber.toString());
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open dialer")),
      );
    }
  }

  // 📍 2. Logout Confirmation Dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Logout Confirmation"),
        content: const Text("Are you sure you want to logout from your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 📍 3. Generate Detailed Invoice PDF (Fixed Table Order & Type Casting)
  Future<void> _generateInvoice(Map<String, dynamic> order, String docId) async {
    final pdf = pw.Document();
    final date = order['timestamp'] != null
        ? (order['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Column(
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
                      pw.Text(order['farmerName']?.toString() ?? 'Verified Farmer'),
                      pw.Text("Phone: ${order['farmerPhone']?.toString() ?? 'N/A'}"),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("BILL TO (Customer):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(order['customerName']?.toString() ?? 'Customer'),
                      pw.Text("Phone: ${order['customerPhone']?.toString() ?? 'N/A'}"),
                      pw.Container(width: 150, child: pw.Text("Addr: ${order['deliveryAddress']?.toString() ?? 'N/A'}", style: const pw.TextStyle(fontSize: 9))),
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
              headers: ['Sr.', 'Product', 'Farmer', 'Price', 'Delivery', 'Qty', 'Total'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: List.generate((order['items'] as List).length, (index) {
                var item = order['items'][index];
                double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                int qty = int.tryParse(item['cartQty']?.toString() ?? '1') ?? 1;
                double delFee = double.tryParse(order['deliveryCharges']?.toString() ?? '0') ?? 0.0;

                return [
                  "${index + 1}",
                  item['name']?.toString() ?? 'N/A',
                  order['farmerName']?.toString() ?? "N/A",
                  "Rs ${price.toStringAsFixed(2)}",
                  "Rs ${delFee.toStringAsFixed(2)}",
                  "$qty",
                  "Rs ${(price * qty).toStringAsFixed(2)}"
                ];
              }),
            ),

            pw.SizedBox(height: 20),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Subtotal: Rs ${order['subtotal']?.toString() ?? '0'}"),
                  pw.Text("Delivery Charges: Rs ${order['deliveryCharges']?.toString() ?? '0'}"),
                  pw.Container(width: 100, child: pw.Divider()),
                  pw.Text("Total Amount: Rs ${order['totalAmount']?.toString() ?? '0'}",
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

  // 📍 4. View Seller Dialog (Fixed empty info)
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
              radius: 35,
              backgroundColor: Color(0xFF4A6D41),
              child: Icon(Icons.storefront, color: Colors.white, size: 35),
            ),
            const SizedBox(height: 15),
            Text(order['farmerName']?.toString() ?? "Farmer Name Not Found",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 5),
            const Text("Verified Agriculture Seller", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: Text(order['farmerPhone']?.toString() ?? "No Phone Number"),
              subtitle: const Text("Tap to call"),
              onTap: () => _makeCall(order['farmerPhone']?.toString(), context),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  // 📍 5. Report Issue Logic
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
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Tell us what happened with your order...",
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue reported successfully.")));
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
        title: const Text("My Orders"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          )
        ],
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
            padding: const EdgeInsets.all(12),
            cacheExtent: 1000, // Smooth scrolling optimization
            physics: const BouncingScrollPhysics(),
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
    String status = order['status']?.toString() ?? "Requested";
    List items = order['items'] as List? ?? [];
    String productNames = items.map((i) => i['name']?.toString() ?? 'N/A').join(", ");
    String farmerReason = order['rejectionReason']?.toString() ?? "No reason provided.";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(productNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
            subtitle: Text("ID: #${docId.substring(0, 8)} | ${order['timestamp'] != null ? DateFormat('dd MMM').format((order['timestamp'] as Timestamp).toDate()) : ''}"),
            trailing: _statusChip(status),
          ),

          // 📍 Rejection Reason UI
          if (status == 'Rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("Reason: $farmerReason", style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
            ),

          const Divider(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton(Icons.person_outline, "Seller", () => _viewSellerProfile(context, order)),
                // 📍 Hide invoice if rejected
                if (status != 'Rejected')
                  _actionButton(Icons.receipt_long_outlined, "Invoice", () => _generateInvoice(order, docId)),
                if (status == 'Delivered')
                  _actionButton(Icons.report_gmailerrorred_outlined, "Issue", () => _showReportIssueSheet(context, docId), color: Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 10),

          if (status == 'Delivered') _RatingManager(order: order, orderId: docId),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (status != 'Delivered' && status != 'Rejected')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makeCall(order['farmerPhone']?.toString(), context),
                      icon: const Icon(Icons.call, size: 18, color: Colors.white),
                      label: const Text("Call Farmer", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41)),
                    ),
                  ),
                if (status == 'Shipping') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(docId).update({'status': 'Delivered'}),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Confirm Received", style: TextStyle(color: Colors.white)),
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

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {Color color = Colors.black87}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _statusChip(String status) {
    Color color = status == 'Delivered' ? Colors.green : (status == 'Rejected' ? Colors.red : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// 📍 Rating Section (Logic Preserved)
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
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => _RatingSheet(order: order, orderId: orderId),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star_outline, color: Colors.orange), SizedBox(width: 10), Text("Rate Products", style: TextStyle(color: Colors.orange))]),
              ),
            ),
          );
        }

        var review = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        int rating = int.tryParse(review['rating']?.toString() ?? '0') ?? 0;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Feedback:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 16))),
              Text("\"${review['review']?.toString() ?? ''}\"", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
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
          const Text("Rate Your Purchase", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 35),
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
                'customerName': FirebaseAuth.instance.currentUser?.displayName ?? "Customer",
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