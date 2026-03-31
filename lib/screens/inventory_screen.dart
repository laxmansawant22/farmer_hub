import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  final List? products;
  const InventoryScreen({super.key, this.products});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  void _deleteProduct(String docId, String productName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(AppTranslations.translate(context, 'confirm_delete')),
        content: Text("${AppTranslations.translate(context, 'delete_warning')} '$productName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.translate(context, 'cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(docId).delete();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$productName ${AppTranslations.translate(context, 'deleted')}")),
                );
              }
            },
            child: Text(AppTranslations.translate(context, 'delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 📍 Header Summary Widget
  Widget _buildInventorySummary(List<QueryDocumentSnapshot> docs) {
    double totalValue = 0;
    int lowStockCount = 0;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      num qty = data['quantity'] ?? 0;
      num price = data['price'] ?? 0;
      // totalStock helps us define what 'low stock' means (e.g., less than 20% of original)
      num totalOriginal = data['totalStock'] ?? qty; 

      totalValue += (qty * price);
      if (qty <= (totalOriginal * 0.2)) lowStockCount++;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF4A6D41).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF4A6D41).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("Stock Value", "₹${totalValue.toStringAsFixed(0)}", Icons.account_balance_wallet),
          const VerticalDivider(thickness: 1, color: Colors.grey),
          _summaryItem("Low Stock", "$lowStockCount Items", Icons.warning_amber_rounded, color: lowStockCount > 0 ? Colors.red : Colors.green),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? const Color(0xFF4A6D41)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppTranslations.translate(context, 'search_crops'),
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('farmerId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)));
          }

          var allDocs = snapshot.data!.docs;
          var filteredDocs = allDocs.where((doc) {
            var name = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? "";
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          if (allDocs.isEmpty) {
            return Center(child: Text(AppTranslations.translate(context, 'no_crops_found')));
          }

          return Column(
            children: [
              if (_searchQuery.isEmpty) _buildInventorySummary(allDocs),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data = filteredDocs[index].data() as Map<String, dynamic>;
                    String docId = filteredDocs[index].id;
                    String base64Image = (data['images'] as List).isNotEmpty ? data['images'][0] : "";

                    // Current stock from DB
                    num remainingStock = data['quantity'] ?? 0;
                    // Original stock level to calculate the progress bar
                    num totalAdded = data['totalStock'] ?? remainingStock;

                    double stockPercentage = totalAdded > 0 ? (remainingStock / totalAdded).clamp(0.0, 1.0) : 0.0;
                    bool isLowStock = remainingStock <= (totalAdded * 0.2);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: base64Image.isNotEmpty
                                      ? Image.memory(base64Decode(base64Image), fit: BoxFit.cover)
                                      : const Icon(Icons.eco, color: Color(0xFF4A6D41)),
                                ),
                              ),
                              title: Text(data['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Text(
                                "₹${data['price']} / ${data['unit'] ?? 'kg'}",
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.green),
                                    onPressed: () {
                                      Map<String, dynamic> editData = Map.from(data);
                                      editData['id'] = docId;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (c) => AddProductScreen(existingProduct: editData)),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteProduct(docId, data['name'] ?? "Crop"),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Total Capacity: ${totalAdded.toStringAsFixed(0)} ${data['unit']}",
                                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Row(
                                        children: [
                                          if (isLowStock && remainingStock > 0)
                                            const Icon(Icons.report_problem, color: Colors.red, size: 14),
                                          Text(
                                            remainingStock <= 0 
                                              ? "OUT OF STOCK" 
                                              : "Available: ${remainingStock.toStringAsFixed(0)} ${data['unit']}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: remainingStock <= 0 ? Colors.red : (isLowStock ? Colors.orange[800] : Colors.blueGrey)
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: stockPercentage,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          remainingStock <= 0 
                                            ? Colors.red 
                                            : (isLowStock ? Colors.orange : const Color(0xFF4A6D41))
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}