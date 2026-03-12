import 'package:flutter/material.dart';
import 'dart:io';
import '../translations.dart'; // 📍 Added translation import
import 'home_screen.dart';
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
            'price': widget.products[actualIndex].price,
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
          price: result['price'],
          unit: result['unit'],
          type: result['type'],
          images: result['images'],
        );
        _runFilter(_searchController.text);
      });
    }
  }

  void _deleteProduct(int index) {
    final productToDelete = _filteredProducts[index];
    final actualIndex = widget.products.indexOf(productToDelete);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(AppTranslations.translate(context, 'confirm_delete')), // 📍 Translated
        content: Text(
            "${AppTranslations.translate(context, 'delete_warning')} '${productToDelete.name}'?"
        ), // 📍 Translated
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.translate(context, 'cancel')), // 📍 Translated
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
                SnackBar(content: Text("${productToDelete.name} ${AppTranslations.translate(context, 'deleted')}")),
              );
            },
            child: Text(
                AppTranslations.translate(context, 'delete'), // 📍 Translated
                style: const TextStyle(color: Colors.white)
            ),
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
          decoration: InputDecoration(
            hintText: AppTranslations.translate(context, 'search_crops'), // 📍 Translated
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ),
      ),
      body: _filteredProducts.isEmpty
          ? Center(child: Text(AppTranslations.translate(context, 'no_crops_found'))) // 📍 Translated
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
                  // 📍 Translated Labels
                  Text("${AppTranslations.translate(context, 'quantity')}: ${item.qty} ${AppTranslations.translate(context, item.unit)}"),
                  Text(
                      "${AppTranslations.translate(context, 'price')}: ₹${item.price} ${AppTranslations.translate(context, 'per')} ${AppTranslations.translate(context, item.unit)}",
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