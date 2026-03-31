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
    // Attempt to get coordinates from productData
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
      // Android: use geo intent
      mapUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    }

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for browsers
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
            stock = data['quantity'] is num ? data['quantity'] : (num.tryParse(data['quantity'].toString()) ?? 0);
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
                      const SizedBox(height: 10),
                      _buildFarmerCard(),
                      const SizedBox(height: 20),
                      _buildDeliveryInfo(isDelivery, deliveryCharge, deliveryReq),
                      const SizedBox(height: 20),
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

  // --- UI Component Helper Methods ---

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

  Widget _buildFarmerCard() {
    return InkWell(
      onTap: _showFarmerProfile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Color(0xFF4A6D41), child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text(AppTranslations.translate(context, 'view_farmer_profile'), style: const TextStyle(fontWeight: FontWeight.bold))),
            const Icon(Icons.chevron_right),
          ],
        ),
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
    return OutlinedButton.icon(
      onPressed: _openMap,
      icon: const Icon(Icons.map_outlined),
      label: Text(AppTranslations.translate(context, 'show_on_map')),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue)
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
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _makeCall(widget.productData['phone'] ?? ""),
            icon: const Icon(Icons.call, color: Colors.white),
            label: Text(AppTranslations.translate(context, 'call_farmer')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: stock <= 0 ? Center(child: Text(AppTranslations.translate(context, 'sold_out'), style: const TextStyle(color: Colors.red)))
              : (_isAddedToCart ? Container(
            height: 55,
            decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: () { if (_quantity > 1) { setState(() => _quantity--); _updateCart(); } }),
                Text("$_quantity $unit", style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add), onPressed: () { if (_quantity < stock) { setState(() => _quantity++); _updateCart(); } }),
              ],
            ),
          )
              : ElevatedButton(
            onPressed: _updateCart,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)),
            child: Text(AppTranslations.translate(context, 'add_to_cart'), style: const TextStyle(color: Colors.white)),
          )),
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

            if (reviews.isEmpty) {
              return Text(AppTranslations.translate(context, 'no_reviews_yet'), style: const TextStyle(color: Colors.grey));
            }

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rev['review'] ?? rev['comment'] ?? ""),
                        if(rev['farmerReply'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(5)),
                            child: Text("Farmer: ${rev['farmerReply']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
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
    _userRating = 5.0; // Reset
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
        initialChildSize: 0.7, maxChildSize: 0.9, expand: false,
        builder: (context, scrollController) => StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(fEmail).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var farmer = snapshot.data?.data() as Map<String, dynamic>?;

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: farmer?['imageUrl'] != null ? MemoryImage(base64Decode(farmer!['imageUrl'])) : null,
                    child: farmer?['imageUrl'] == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: Text(farmer?['name'] ?? "Farmer", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                const Divider(height: 30),
                _infoRow(Icons.location_on, AppTranslations.translate(context, 'farm_location'), farmer?['address'] ?? "N/A"),
                _infoRow(Icons.history, AppTranslations.translate(context, 'experience'), farmer?['experience'] ?? "Verified Farmer"),
                const SizedBox(height: 20),
                _buildReviewSection(fEmail),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A6D41)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))])),
        ],
      ),
    );
  }
}