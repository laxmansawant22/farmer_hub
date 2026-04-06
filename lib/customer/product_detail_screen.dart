import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../translations.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailsScreen({super.key, required this.productData});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  bool _isAddedToCart = false;
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 5.0;

  @override
  void initState() {
    super.initState();
    int index = globalCart.indexWhere((item) => item['id'] == widget.productData['id']);
    if (index != -1) {
      _quantity = globalCart[index]['cartQty'];
      _isAddedToCart = true;
    }
  }

  void _openMap() async {
    double? lat = widget.productData['lat'] != null ? double.tryParse(widget.productData['lat'].toString()) : null;
    double? lng = widget.productData['lng'] != null ? double.tryParse(widget.productData['lng'].toString()) : null;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate(context, 'location_not_available'))),
      );
      return;
    }

    Uri mapUri;
    if (Platform.isIOS) {
      mapUri = Uri.parse("https://maps.apple.com/?q=$lat,$lng");
    } else {
      mapUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    }

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        final googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps")));
    }
  }

  void _updateCart() {
    int index = globalCart.indexWhere((item) => item['id'] == widget.productData['id']);
    if (index != -1) {
      setState(() {
        globalCart[index]['cartQty'] = _quantity;
      });
    } else {
      Map<String, dynamic> cartItem = Map.from(widget.productData);
      cartItem['cartQty'] = _quantity;
      globalCart.add(cartItem);
      setState(() => _isAddedToCart = true);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Cart"), duration: Duration(seconds: 1)));
  }

  void _confirmCall(String phoneNumber) {
    if (phoneNumber.isEmpty || phoneNumber == "null") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Farmer phone number not available")));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Call Farmer?"),
        content: Text("Do you want to call $phoneNumber?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _makeCall(phoneNumber);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Call Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch dialer")));
    }
  }

  void _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a comment")));
      return;
    }

    String farmerEmail = widget.productData['farmerEmail'].toString().trim();
    await FirebaseFirestore.instance.collection('reviews').add({
      'farmerEmail': farmerEmail,
      'farmerId': widget.productData['farmerId'],
      'productId': widget.productData['id'],
      'customerName': user.displayName ?? "Customer",
      'rating': _userRating,
      'review': _reviewController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _reviewController.clear();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate(context, 'review_submitted')), backgroundColor: Colors.green)
    );
  }

  @override
  Widget build(BuildContext context) {
    String base64Image = (widget.productData['images'] as List).isNotEmpty ? widget.productData['images'][0] : "";
    double price = double.tryParse(widget.productData['price'].toString()) ?? 0.0;
    String unit = widget.productData['unit'] ?? "kg";
    String method = widget.productData['method'] ?? "Organic";
    String fEmail = widget.productData['farmerEmail']?.toString().trim() ?? "";

    bool isDelivery = widget.productData['isDeliveryAvailable'] ?? false;
    num deliveryCharge = widget.productData['deliveryCharge'] ?? 0;
    String deliveryReq = widget.productData['deliveryRequirements'] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productData['name'] ?? AppTranslations.translate(context, 'details')),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen())),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('products').doc(widget.productData['id']).snapshots(),
        builder: (context, snapshot) {
          num stock = 0;
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            stock = (num.tryParse(data['quantity'].toString()) ?? 0);
          }

          // Safety check: reset quantity if it exceeds current live stock
          if (_quantity > stock && stock > 0) {
            _quantity = stock.toInt();
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageHeader(base64Image, method),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainDetails(price, unit),
                      const SizedBox(height: 15),
                      _buildFarmerMiniRow(),
                      const SizedBox(height: 20),
                      _buildDeliveryInfo(isDelivery, deliveryCharge, deliveryReq),
                      const SizedBox(height: 25),
                      _buildMapButton(),
                      const SizedBox(height: 15),
                      _buildStockText(stock, unit),
                      const Divider(height: 30),
                      _buildDescription(),
                      const SizedBox(height: 30),
                      _buildActionButtons(stock, unit),
                      const Divider(height: 40),
                      _buildReviewSection(fEmail),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageHeader(String base64Image, String method) {
    return Stack(
      children: [
        Container(
          height: 280, width: double.infinity, color: Colors.grey[200],
          child: base64Image.isNotEmpty ? Image.memory(base64Decode(base64Image), fit: BoxFit.cover) : const Icon(Icons.image, size: 100),
        ),
        Positioned(
          top: 15, left: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: method == "Organic" ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.white, size: 16),
                const SizedBox(width: 5),
                Text(method, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainDetails(double price, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.productData['name'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text("₹$price/$unit", style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFarmerMiniRow() {
    return InkWell(
      onTap: _showFarmerProfile,
      child: Row(
        children: [
          const CircleAvatar(radius: 14, backgroundColor: Color(0xFF4A6D41), child: Icon(Icons.person, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Text(AppTranslations.translate(context, 'view_farmer_profile'), style: const TextStyle(fontSize: 14, color: Colors.blueGrey, decoration: TextDecoration.underline)),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo(bool isDelivery, num charge, String req) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDelivery ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDelivery ? Colors.green[100]! : Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isDelivery ? Icons.delivery_dining : Icons.store_mall_directory, color: isDelivery ? Colors.green : Colors.red),
              const SizedBox(width: 10),
              Text(
                isDelivery ? "Home Delivery Available" : "Self-Pickup Only",
                style: TextStyle(fontWeight: FontWeight.bold, color: isDelivery ? Colors.green[800] : Colors.red[800]),
              ),
            ],
          ),
          if (isDelivery) ...[
            const SizedBox(height: 8),
            Text("Charges: ₹$charge", style: const TextStyle(fontWeight: FontWeight.w600)),
            if (req.isNotEmpty)
              Text("Requirement: $req", style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ]
        ],
      ),
    );
  }

  Widget _buildMapButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openMap,
        icon: const Icon(Icons.location_on_outlined),
        label: Text(AppTranslations.translate(context, 'show_on_map'), style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: const Color(0xFF2E7D32),
            side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
      ),
    );
  }

  Widget _buildStockText(num stock, String unit) {
    return Text(stock > 0 ? "${AppTranslations.translate(context, 'stock_available')}: ${stock.toStringAsFixed(0)} $unit" : AppTranslations.translate(context, 'out_of_stock'),
        style: TextStyle(color: stock <= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold));
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppTranslations.translate(context, 'description'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(widget.productData['description'] ?? "", style: const TextStyle(fontSize: 15, height: 1.4)),
      ],
    );
  }

  Widget _buildActionButtons(num stock, String unit) {
    String phone = widget.productData['phone']?.toString() ?? "";

    return Column(
      children: [
        if (!_isAddedToCart && stock > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () { if (_quantity > 1) setState(() => _quantity--); },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text("$_quantity $unit", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  onPressed: () { if (_quantity < stock) setState(() => _quantity++); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmCall(phone), 
                icon: const Icon(Icons.call, color: Colors.white),
                label: Text(AppTranslations.translate(context, 'call_farmer')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: stock <= 0 ? Center(child: Text(AppTranslations.translate(context, 'sold_out'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                  : (_isAddedToCart ? Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                child: const Text("In Cart ✔", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              )
                  : ElevatedButton(
                onPressed: _updateCart,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)),
                child: Text(AppTranslations.translate(context, 'add_to_cart'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewSection(String farmerEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppTranslations.translate(context, 'customer_reviews'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: _showRatingDialog, child: const Text("Write a Review", style: TextStyle(color: Color(0xFF4A6D41)))),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('reviews')
              .where('farmerEmail', isEqualTo: farmerEmail)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var reviews = snapshot.data!.docs;
            if (reviews.isEmpty) return Text(AppTranslations.translate(context, 'no_reviews_yet'), style: const TextStyle(color: Colors.grey));

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length > 5 ? 5 : reviews.length,
              itemBuilder: (context, index) {
                var rev = reviews[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF4A6D41), child: Icon(Icons.person, color: Colors.white, size: 20)),
                    title: Row(
                      children: [
                        Text(rev['customerName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        Text(" ${rev['rating']}", style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    subtitle: Text(rev['review'] ?? rev['comment'] ?? ""),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showRatingDialog() {
    _userRating = 5.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.translate(context, 'rate_farmer')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(builder: (context, setDialogState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(Icons.star, color: _userRating > index ? Colors.orange : Colors.grey),
                  onPressed: () => setDialogState(() => _userRating = index + 1.0),
                )),
              );
            }),
            TextField(controller: _reviewController, decoration: InputDecoration(hintText: AppTranslations.translate(context, 'write_comment'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.translate(context, 'cancel'))),
          ElevatedButton(onPressed: _submitReview, child: Text(AppTranslations.translate(context, 'submit'))),
        ],
      ),
    );
  }

  void _showFarmerProfile() {
    String fEmail = widget.productData['farmerEmail']?.toString().trim() ?? "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5, maxChildSize: 0.7, expand: false,
        builder: (context, scrollController) => StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(fEmail).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var farmer = snapshot.data?.data() as Map<String, dynamic>?;

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(25),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 45,
                    backgroundImage: (farmer?['imageUrl'] != null && farmer!['imageUrl'].toString().isNotEmpty)
                        ? MemoryImage(base64Decode(farmer['imageUrl']))
                        : null,
                    child: farmer?['imageUrl'] == null ? const Icon(Icons.person, size: 45) : null,
                  ),
                ),
                const SizedBox(height: 15),
                Center(child: Text(farmer?['name'] ?? "Farmer", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 5),
                const Center(child: Text("Verified AgriMarket Partner", style: TextStyle(color: Colors.green, fontSize: 13))),
                const Divider(height: 40),
                _infoRow(Icons.location_on_outlined, AppTranslations.translate(context, 'farm_location'), farmer?['address'] ?? "Address not provided"),
                _infoRow(Icons.history_edu_outlined, AppTranslations.translate(context, 'experience'), farmer?['experience'] ?? "Experienced Farmer"),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF4A6D41), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))])),
        ],
      ),
    );
  }
}