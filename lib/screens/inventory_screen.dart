import 'package:flutter/material.dart';
import 'dart:io';
import 'home_screen.dart'; // To access the Product model
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  final List<Product> products;
  const InventoryScreen({super.key, required this.products});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  // 🔍 Search Logic
  void _runFilter(String enteredKeyword) {
    List<Product> results = [];
    if (enteredKeyword.isEmpty) {
      results = widget.products;
    } else {
      results = widget.products
          .where((product) =>
          product.name.toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  // 📝 Edit Logic (Handles the new Price field)
  void _editProduct(int index) async {
    final productToEdit = _filteredProducts[index];
    final actualIndex = widget.products.indexOf(productToEdit);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          existingProduct: {
            'name': widget.products[actualIndex].name,
            'qty': widget.products[actualIndex].qty,
            'price': widget.products[actualIndex].price, // 📍 Passing price
            'unit': widget.products[actualIndex].unit,
            'type': widget.products[actualIndex].type,
            'images': widget.products[actualIndex].images,
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        widget.products[actualIndex] = Product(
          name: result['name'],
          qty: result['qty'],
          price: result['price'], // 📍 Saving updated price
          unit: result['unit'],
          type: result['type'],
          images: result['images'],
        );
        _runFilter(_searchController.text);
      });
    }
  }

  // 🗑️ Delete Logic with Confirmation
  void _deleteProduct(int index) {
    final productToDelete = _filteredProducts[index];
    final actualIndex = widget.products.indexOf(productToDelete);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to remove '${productToDelete.name}' from your inventory?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                widget.products.removeAt(actualIndex);
                _runFilter(_searchController.text);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${productToDelete.name} deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: TextField(
          controller: _searchController,
          onChanged: (value) => _runFilter(value),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search your crops...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
          ),
        ),
      ),
      body: _filteredProducts.isEmpty
          ? const Center(child: Text("No crops found in inventory"))
          : ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final item = _filteredProducts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                    item.images[0],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover
                ),
              ),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Quantity: ${item.qty} ${item.unit}"),
                  Text(
                      "Price: ₹${item.price} per ${item.unit}",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: () => _editProduct(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteProduct(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}