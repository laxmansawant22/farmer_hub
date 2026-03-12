import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../translations.dart'; // 📍 Added translation import

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

  String _selectedUnit = 'kg';
  String _selectedType = 'Vegetable';
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameController.text = widget.existingProduct!['name'];
      _qtyController.text = widget.existingProduct!['qty'];
      _priceController.text = widget.existingProduct!['price'] ?? "";
      _selectedUnit = widget.existingProduct!['unit'];
      _selectedType = widget.existingProduct!['type'];
      _images = List<File>.from(widget.existingProduct!['images']);
    }
  }

  Future<void> _pickImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _images.add(File(photo.path));
      });
    }
  }

  void _submitData() {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppTranslations.translate(context, 'error_photo_required')), // 📍 Translated
            backgroundColor: Colors.red
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'qty': _qtyController.text.trim(),
        'price': _priceController.text.trim(),
        'unit': _selectedUnit,
        'type': _selectedType,
        'images': _images,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 📍 Dynamic Title
        title: Text(widget.existingProduct == null
            ? AppTranslations.translate(context, 'add_new_crop')
            : AppTranslations.translate(context, 'edit_crop')),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  AppTranslations.translate(context, 'capture_photos'), // 📍 Translated
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_images[index], width: 100, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(index)),
                              child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: AppTranslations.translate(context, 'product_name'), // 📍 Translated
                    border: const OutlineInputBorder()
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? AppTranslations.translate(context, 'err_crop_name') // 📍 Translated
                    : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppTranslations.translate(context, 'price_per_unit'), // 📍 Translated
                  prefixText: "₹ ",
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return AppTranslations.translate(context, 'err_price');
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return AppTranslations.translate(context, 'err_invalid');
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: AppTranslations.translate(context, 'quantity'), // 📍 Translated
                          border: const OutlineInputBorder()
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return AppTranslations.translate(context, 'err_required');
                        if (double.tryParse(value) == null || double.parse(value) <= 0) return AppTranslations.translate(context, 'err_invalid');
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      // 📍 Logic to translate units while keeping the backend keys
                      items: ['kg', 'quintal', 'ton', 'piece'].map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(AppTranslations.translate(context, u))
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                    labelText: AppTranslations.translate(context, 'crop_type'), // 📍 Translated
                    border: const OutlineInputBorder()
                ),
                // 📍 Logic to translate types while keeping the backend keys
                items: ['Vegetable', 'Fruit', 'Grain', 'Pulse'].map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(AppTranslations.translate(context, t.toLowerCase()))
                )).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6D41),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  widget.existingProduct == null
                      ? AppTranslations.translate(context, 'list_product')
                      : AppTranslations.translate(context, 'update_product'), // 📍 Translated
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}