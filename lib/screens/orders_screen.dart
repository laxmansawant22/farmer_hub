import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? farmerEmail = FirebaseAuth.instance.currentUser?.email;
  final TextEditingController _rejectReasonController = TextEditingController();

  // Search logic
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  // 📍 Function to handle Invoice Download (Link this to your PDF Logic)
  void _downloadInvoice(Map<String, dynamic> order) {
    // Implement your PDF generation logic here, similar to your Sales Screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Generating Invoice for ${order['productName']}...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders Dashboard"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Search product name...",
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4A6D41)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "Incoming"),
                  Tab(text: "Pending"),
                  Tab(text: "Completed"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(['New Order']),
          _buildOrderList(['Pending']),
          _buildOrderList(['Shipped', 'Shipping', 'Delivered', 'Completed', 'Received']),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<String> queryStatuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('farmer_orders')
          .where('farmerEmail', isEqualTo: farmerEmail)
          .where('status', whereIn: queryStatuses)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No orders found in this section."));
        }

        var filteredDocs = snapshot.data!.docs.where((doc) {
          String prodName = (doc['productName'] ?? "").toString().toLowerCase();
          return prodName.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No products match your search."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var order = filteredDocs[index].data() as Map<String, dynamic>;
            String docId = filteredDocs[index].id;

            double itemTotal = ((order['price'] ?? 0) * (order['qty'] ?? 0)).toDouble();
            double delCharge = double.tryParse(order['deliveryCharge']?.toString() ?? '0') ?? 0.0;
            double grandTotal = itemTotal + delCharge;

            String formattedDate = "N/A";
            if (order['timestamp'] != null) {
              DateTime dt = (order['timestamp'] as Timestamp).toDate();
              formattedDate = DateFormat('dd MMM, hh:mm a').format(dt);
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                title: Text(
                    order['productName'] ?? "Unknown Product",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text("Qty: ${order['qty']} ${order['unit'] ?? ''} | Total: ₹${grandTotal.toStringAsFixed(2)}"),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                trailing: _statusSmallChip(order['status'] ?? "New Order"),
                onTap: () => _showOrderDetails(order, docId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusSmallChip(String status) {
    Color color;
    switch (status) {
      case 'Delivered':
      case 'Completed':
      case 'Received':
        color = Colors.green;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Shipping':
      case 'Shipped':
        color = Colors.blue;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
          status,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order, String docId) async {
    var customerSnap = await FirebaseFirestore.instance.collection('users').doc(order['customerEmail']).get();
    var customerData = customerSnap.data();

    double itemTotal = (order['price'] * order['qty']).toDouble();
    double delCharge = double.tryParse(order['deliveryCharge']?.toString() ?? '0') ?? 0.0;
    double totalEarnings = itemTotal + delCharge;
    bool hasHomeDelivery = delCharge > 0;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Order Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                // 📍 INVOICE DOWNLOAD BUTTON
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4A6D41)),
                  onPressed: () => _downloadInvoice(order),
                ),
              ],
            ),
            const Divider(),
            _detailRow("Product", order['productName']),
            _detailRow("Quantity", "${order['qty']} ${order['unit']}"),
            _detailRow("Items Price", "₹$itemTotal"),
            _detailRow("Delivery Fee", delCharge == 0 ? "Self Pickup" : "₹$delCharge"),
            const Divider(),
            _detailRow("Total Earnings", "₹$totalEarnings", isBold: true),
            const SizedBox(height: 20),
            const Text("Customer Info", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            _detailRow("Name", customerData?['name'] ?? "N/A"),
            _detailRow("Phone", customerData?['phone'] ?? "N/A"),
            _detailRow("Address", customerData?['address'] ?? "N/A"),
            const SizedBox(height: 20),
            Row(
              children: [
                if (order['status'] == 'New Order') ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmDialog(context, "Confirm Order?", "Accept this request?", () {
                        _updateStatus(docId, 'Pending', order['mainOrderId']);
                      }),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showRejectReasonDialog(docId, order['mainOrderId']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Reject", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
                if (order['status'] == 'Pending')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmDialog(
                          context,
                          hasHomeDelivery ? "Start Shipping?" : "Confirm Delivery?",
                          hasHomeDelivery ? "Mark this as shipped to the customer." : "Mark this as delivered (Customer is picking up).",
                              () {
                            String nextStatus = hasHomeDelivery ? 'Shipping' : 'Delivered';
                            _updateStatus(docId, nextStatus, order['mainOrderId']);
                          }
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: hasHomeDelivery ? Colors.blue : Colors.green),
                      child: Text(
                          hasHomeDelivery ? "Mark as Shipping" : "Mark as Delivered / Picked Up",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showRejectReasonDialog(String docId, String mainOrderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Order"),
        content: TextField(
          controller: _rejectReasonController,
          decoration: const InputDecoration(hintText: "Reason for rejection"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (_rejectReasonController.text.isNotEmpty) {
                _updateStatus(docId, 'Rejected', mainOrderId, reason: _rejectReasonController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  void _confirmDialog(BuildContext context, String title, String msg, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  void _updateStatus(String docId, String newStatus, String mainOrderId, {String? reason}) async {
    try {
      await FirebaseFirestore.instance.collection('farmer_orders').doc(docId).update({
        'status': newStatus,
        if (reason != null) 'rejectReason': reason,
      });
      await FirebaseFirestore.instance.collection('orders').doc(mainOrderId).update({
        'status': newStatus,
        if (reason != null) 'rejectReason': reason,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order is now $newStatus"), backgroundColor: const Color(0xFF4A6D41))
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _detailRow(String label, String? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value ?? "N/A", style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}