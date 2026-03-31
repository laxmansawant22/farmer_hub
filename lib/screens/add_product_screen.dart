import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // For Base64 image conversion
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // 📍 Added for automatic location
import '../translations.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProduct;
  const AddProductScreen({super.key, this.existingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // 📍 New Controllers for Delivery
  final TextEditingController _deliveryChargeController = TextEditingController();
  final TextEditingController _deliveryReqController = TextEditingController();

  final TextEditingController _otherTypeController = TextEditingController();
  final TextEditingController _otherMethodController = TextEditingController();

  String _selectedUnit = 'kg';
  String? _selectedType;
  String? _farmingMethod;

  // 📍 Delivery State
  bool _isDeliveryAvailable = false;

  List<String> _base64Images = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _autoFetchLocation();
    if (widget.existingProduct != null) {
      _nameController.text = widget.existingProduct!['name'] ?? "";
      _qtyController.text = widget.existingProduct!['quantity'].toString();
      _priceController.text = widget.existingProduct!['price'].toString();
      _descController.text = widget.existingProduct!['description'] ?? "";
      _selectedUnit = widget.existingProduct!['unit'] ?? 'kg';

      // 📍 Load Delivery Data
      _isDeliveryAvailable = widget.existingProduct!['isDeliveryAvailable'] ?? false;
      _deliveryChargeController.text = widget.existingProduct!['deliveryCharge']?.toString() ?? "";
      _deliveryReqController.text = widget.existingProduct!['deliveryRequirements'] ?? "";

      List<String> standardTypes = ['Vegetables', 'Fruits', 'Seeds'];
      String existingType = widget.existingProduct!['type'] ?? "";
      if (standardTypes.contains(existingType)) {
        _selectedType = existingType;
      } else if (existingType.isNotEmpty) {
        _selectedType = 'Other';
        _otherTypeController.text = existingType;
      }

      List<String> standardMethods = ['Organic', 'Chemical'];
      String existingMethod = widget.existingProduct!['method'] ?? "";
      if (standardMethods.contains(existingMethod)) {
        _farmingMethod = existingMethod;
      } else if (existingMethod.isNotEmpty) {
        _farmingMethod = 'Other';
        _otherMethodController.text = existingMethod;
      }

      _base64Images = List<String>.from(widget.existingProduct!['images'] ?? []);
      _lat = widget.existingProduct!['lat'];
      _lng = widget.existingProduct!['lng'];
    }
  }

  Future<void> _autoFetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (e) {
      debugPrint("Auto-location error: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 25, maxWidth: 800, maxHeight: 800);
      if (photo != null) {
        setState(() => _isLoading = true);
        File file = File(photo.path);
        List<int> imageBytes = await file.readAsBytes();
        String base64String = base64Encode(imageBytes);
        setState(() {
          _base64Images.add(base64String);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _submitData() async {
    if (_base64Images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.translate(context, 'error_photo_required')), backgroundColor: Colors.red));
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedType == null || _farmingMethod == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a category and method"), backgroundColor: Colors.orange));
        return;
      }

      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw "User not logged in.";

        double priceValue = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        double newQtyValue = double.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        double initialQty = newQtyValue; // keeps the original stock for percent/availability UI
        double deliveryCharge = double.tryParse(_deliveryChargeController.text) ?? 0.0;

        String finalType = (_selectedType == 'Other') ? _otherTypeController.text.trim() : _selectedType!;
        String finalMethod = (_farmingMethod == 'Other') ? _otherMethodController.text.trim() : _farmingMethod!;

        final productData = {
          'name': _nameController.text.trim(),
          'quantity': newQtyValue,
          'totalStock': initialQty,
          'price': priceValue,
          'description': _descController.text.trim(),
          'unit': _selectedUnit,
          'type': finalType,
          'method': finalMethod,
          'images': _base64Images,
          'farmerId': user.uid,
          'farmerEmail': user.email ?? "no-email",
          'timestamp': FieldValue.serverTimestamp(),
          'lat': _lat,
          'lng': _lng,
          // 📍 New Delivery Fields
          'isDeliveryAvailable': _isDeliveryAvailable,
          'deliveryCharge': _isDeliveryAvailable ? deliveryCharge : 0.0,
          'deliveryRequirements': _isDeliveryAvailable ? _deliveryReqController.text.trim() : "",
        };

        if (widget.existingProduct == null) {
          productData['totalStock'] = newQtyValue;
          await FirebaseFirestore.instance.collection('products').add(productData);
        } else {
          String docId = widget.existingProduct!['id'];
          double oldQty = double.tryParse(widget.existingProduct!['quantity'].toString()) ?? 0.0;
          double currentTotalStock = double.tryParse(widget.existingProduct!['totalStock']?.toString() ?? oldQty.toString()) ?? oldQty;

          if (newQtyValue > oldQty) {
            double difference = newQtyValue - oldQty;
            productData['totalStock'] = currentTotalStock + difference;
          } else {
            productData['totalStock'] = currentTotalStock;
          }

          await FirebaseFirestore.instance.collection('products').doc(docId).update(productData);
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Saved Successfully!"), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProduct == null ? "Add New Crop" : "Edit Crop"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppTranslations.translate(context, 'capture_photos'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _base64Images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _base64Images.length) {
                      return GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.camera_alt, color: Colors.grey),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_base64Images[index]), width: 100, height: 100, fit: BoxFit.cover)),
                          Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => setState(() => _base64Images.removeAt(index)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),

              const Text("Product Category", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                hint: const Text("Choose Category"),
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: ['Vegetables', 'Fruits', 'Seeds', 'Other']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedType = val),
                validator: (val) => val == null ? "Select category" : null,
              ),
              if (_selectedType == 'Other') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _otherTypeController,
                  decoration: const InputDecoration(labelText: "Type your category", border: OutlineInputBorder()),
                  validator: (val) => (val == null || val.isEmpty) ? "Specify the category" : null,
                ),
              ],
              const SizedBox(height: 20),

              const Text("Farming Method", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _farmingMethod,
                hint: const Text("Choose Method"),
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: ['Organic', 'Chemical', 'Other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _farmingMethod = val),
                validator: (val) => val == null ? "Select method" : null,
              ),
              if (_farmingMethod == 'Other') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _otherMethodController,
                  decoration: const InputDecoration(labelText: "Type your farming method", border: OutlineInputBorder()),
                  validator: (val) => (val == null || val.isEmpty) ? "Specify the method" : null,
                ),
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Icon(_lat != null ? Icons.location_on : Icons.location_searching, size: 16, color: _lat != null ? Colors.green : Colors.orange),
                  const SizedBox(width: 5),
                  Text(_lat != null ? "Location Captured" : "Fetching location...", style: TextStyle(fontSize: 12, color: _lat != null ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: AppTranslations.translate(context, 'product_name'), border: const OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? "Enter name" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(labelText: AppTranslations.translate(context, 'description'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // 📍 DELIVERY SECTION
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Home Delivery Available?", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: _isDeliveryAvailable,
                      activeColor: const Color(0xFF4A6D41),
                      onChanged: (val) => setState(() => _isDeliveryAvailable = val),
                    ),
                    if (_isDeliveryAvailable) ...[
                      const Divider(),
                      TextFormField(
                        controller: _deliveryChargeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Delivery Charges (₹)", prefixText: "₹ ", border: OutlineInputBorder()),
                        validator: (val) => (_isDeliveryAvailable && (val == null || val.isEmpty)) ? "Enter charges" : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _deliveryReqController,
                        decoration: const InputDecoration(labelText: "Delivery Requirements (e.g. Min 5kg)", hintText: "Optional", border: OutlineInputBorder()),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppTranslations.translate(context, 'price_per_unit'), prefixText: "₹ ", border: const OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? "Enter price" : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: AppTranslations.translate(context, 'quantity'), border: const OutlineInputBorder()),
                      validator: (value) => (value == null || value.isEmpty) ? "Enter quantity" : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: ['kg', 'quintal', 'ton', 'piece'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), minimumSize: const Size(double.infinity, 55)),
                child: Text(widget.existingProduct == null ? "List Product" : "Update Product", style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}