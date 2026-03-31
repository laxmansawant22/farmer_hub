import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../translations.dart';

class FarmerReviewsScreen extends StatefulWidget {
  const FarmerReviewsScreen({super.key});

  @override
  State<FarmerReviewsScreen> createState() => _FarmerReviewsScreenState();
}

class _FarmerReviewsScreenState extends State<FarmerReviewsScreen> {
  final TextEditingController _replyController = TextEditingController();
  int? _selectedFilter; // null means "All", otherwise 1-5

  // 📍 Function to save farmer's reply to Firestore
  void _submitReply(String docId) async {
    if (_replyController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('reviews').doc(docId).update({
        'farmerReply': _replyController.text.trim(),
        'replyTimestamp': FieldValue.serverTimestamp(),
      });

      _replyController.clear();
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reply sent!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // 📍 Dialog to type the reply
  void _showReplyDialog(String docId, String customerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Reply to $customerName"),
        content: TextField(
          controller: _replyController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Ask what the problem is or thank them...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6D41),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _submitReply(docId),
            child: const Text("Send", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Note: We use the UID to ensure the farmer sees only reviews meant for them
    final String farmerUid = user?.uid ?? "";

    // 📍 Real-time query filtered by farmerId
    Query reviewQuery = FirebaseFirestore.instance
        .collection('reviews')
        .where('farmerId', isEqualTo: farmerUid);

    if (_selectedFilter != null) {
      reviewQuery = reviewQuery.where('rating', isEqualTo: _selectedFilter);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate(context, 'my_reviews')),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 📍 Rating Filter Bar
          _buildFilterBar(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: reviewQuery.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)));
                }

                var reviews = snapshot.data!.docs;

                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(_selectedFilter == null 
                          ? "No reviews yet" 
                          : "No $_selectedFilter-star reviews found"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    var data = reviews[index].data() as Map<String, dynamic>;
                    String docId = reviews[index].id;
                    String customerName = data['customerName'] ?? "Anonymous";
                    bool hasReply = data.containsKey('farmerReply') && data['farmerReply'] != null;
                    int rating = data['rating'] ?? 0;
                    String reviewText = data['review'] ?? data['comment'] ?? "No comment provided.";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: rating <= 2 ? Colors.red.withOpacity(0.2) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: rating <= 2 ? Colors.red[100] : const Color(0xFF4A6D41),
                                      radius: 18,
                                      child: Icon(Icons.person, color: rating <= 2 ? Colors.red : Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if(data['timestamp'] != null)
                                          Text(
                                            DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate()),
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                _starBadge(rating.toString()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // The Customer's Comment
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reviewText, 
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (hasReply)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.reply, size: 14, color: Colors.green),
                                        const SizedBox(width: 5),
                                        Text("Your Response:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(data['farmerReply'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                                  ],
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showReplyDialog(docId, customerName),
                                  icon: Icon(rating <= 2 ? Icons.support_agent : Icons.chat_bubble_outline, size: 16),
                                  label: Text(rating <= 2 ? "Resolve Issue" : "Send Thanks"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: rating <= 2 ? Colors.red : const Color(0xFF4A6D41),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          _filterChip(null, "All"),
          _filterChip(5, "5 ★"),
          _filterChip(4, "4 ★"),
          _filterChip(3, "3 ★"),
          _filterChip(2, "2 ★"),
          _filterChip(1, "1 ★"),
        ],
      ),
    );
  }

  Widget _filterChip(int? rating, String label) {
    bool isSelected = _selectedFilter == rating;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = selected ? rating : null;
          });
        },
        selectedColor: const Color(0xFF4A6D41),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _starBadge(String rating) {
    int r = int.tryParse(rating) ?? 0;
    Color color = r <= 2 ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: color, size: 16),
          Text(" $rating", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}