import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📍 Global cart list
List<Map<String, dynamic>> globalCart = [];

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessing = false;

  // 📍 Logic to calculate total item price
  double get subtotal {
    return globalCart.fold(0, (sum, item) => sum + (item['price'] * item['cartQty']));
  }

  // 📍 Logic to calculate delivery charges
  double get totalDeliveryCharge {
    double totalCharge = 0;
    Set<String> processedFarmers = {};

    for (var item in globalCart) {
      String farmerEmail = item['farmerEmail'];
      bool isDelivery = item['isDeliveryAvailable'] ?? false;
      double charge = double.tryParse(item['deliveryCharge']?.toString() ?? '0') ?? 0.0;

      // Only add charge if delivery is available and we haven't charged for this farmer yet
      if (isDelivery && !processedFarmers.contains(farmerEmail)) {
        totalCharge += charge;
        processedFarmers.add(farmerEmail);
      }
    }
    return totalCharge;
  }

  double get grandTotal => subtotal + totalDeliveryCharge;

  void _updateQuantity(int index, bool isIncrement) {
    setState(() {
      if (isIncrement) {
        globalCart[index]['cartQty']++;
      } else {
        if (globalCart[index]['cartQty'] > 1) {
          globalCart[index]['cartQty']--;
        }
      }
    });
  }

  Future<void> _processRequestToSell() async {
    if (globalCart.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Please login to place a request");

      // 📍 1. Prepare a Firestore Batch to update stock and orders simultaneously
      WriteBatch batch = FirebaseFirestore.instance.batch();

      String orderId = FirebaseFirestore.instance.collection('orders').doc().id;

      final orderData = {
        'orderId': orderId,
        'customerId': user.uid,
        'customerEmail': user.email,
        'items': globalCart,
        'subtotal': subtotal,
        'deliveryCharges': totalDeliveryCharge,
        'totalAmount': grandTotal,
        'status': 'Requested',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 📍 2. Add Main Order to Batch
      DocumentReference orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      batch.set(orderRef, orderData);

      for (var item in globalCart) {
        // 📍 3. Add Individual Farmer Orders to Batch
        DocumentReference farmerOrderRef = FirebaseFirestore.instance.collection('farmer_orders').doc();
        batch.set(farmerOrderRef, {
          'mainOrderId': orderId,
          'farmerEmail': item['farmerEmail'],
          'productName': item['name'],
          'qty': item['cartQty'],
          'unit': item['unit'],
          'price': item['price'],
          'deliveryCharge': (item['isDeliveryAvailable'] ?? false) ? item['deliveryCharge'] : 0,
          'customerEmail': user.email,
          'status': 'New Order',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 📍 4. STOCK REDUCTION LOGIC (The critical fix)
        // This targets the product in the 'products' collection and subtracts the cart quantity
        DocumentReference productRef = FirebaseFirestore.instance.collection('products').doc(item['id']);
        batch.update(productRef, {
          'quantity': FieldValue.increment(-item['cartQty']), 
        });
      }

      // 📍 5. Execute all database changes at once
      await batch.commit();

      if (!mounted) return;

      setState(() {
        globalCart.clear();
        _isProcessing = false;
      });

      _showSuccessDialog();

    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.send_rounded, color: Color(0xFF4A6D41), size: 60),
        content: const Text(
          "Request Sent!\n\nThe farmer will review your request. You can track the status in 'My Orders'.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF4A6D41), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)))
          : globalCart.isEmpty
          ? const Center(child: Text("Your cart is empty"))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: globalCart.length,
              itemBuilder: (context, index) {
                final item = globalCart[index];
                String base64Image = (item['images'] as List).isNotEmpty ? item['images'][0] : "";
                bool isDelivery = item['isDeliveryAvailable'] ?? false;
                double dCharge = double.tryParse(item['deliveryCharge']?.toString() ?? '0') ?? 0.0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: base64Image.isNotEmpty
                            ? Image.memory(base64Decode(base64Image), width: 60, height: 60, fit: BoxFit.cover)
                            : const Icon(Icons.eco, size: 40),
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("₹${item['price']} / ${item['unit']}"),
                          Text("Seller: ${item['farmerEmail']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (isDelivery)
                            Text("Delivery: ₹$dCharge", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                          else
                            const Text("Self-Pickup", style: TextStyle(fontSize: 11, color: Colors.orange)),
                        ],
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18, color: Colors.red),
                              onPressed: () => _updateQuantity(index, false),
                            ),
                            Text(
                                item['cartQty'].toString(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18, color: Colors.green),
                              onPressed: () => _updateQuantity(index, true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtotal:", style: TextStyle(fontSize: 16)),
                    Text("₹${subtotal.toStringAsFixed(2)}"),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Delivery Charges:", style: TextStyle(fontSize: 16)),
                    Text("₹${totalDeliveryCharge.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Amount:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("₹${grandTotal.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
                  ],
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: _processRequestToSell,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6D41),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                      "Request to Sell",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}