import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'chat_screen.dart'; // 

class ProductDetailCloud extends StatelessWidget {
  final Map<String, dynamic> productData;
  const ProductDetailCloud({super.key, required this.productData});
  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color cloudColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: cloudColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: productData['imageUrl'] != null && productData['imageUrl'].isNotEmpty
                ? Image.network(productData['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 200, width: double.infinity, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, color: Colors.grey)), // Fallback si no hay imagen
          ),
          const SizedBox(height: 20),
          Text(productData['title'] ?? 'Sin título', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('\$${productData['price'] ?? '0'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFAF0303))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.school, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(productData['universitySede'] ?? 'Sede Principal', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(width: 15),
              const Icon(Icons.near_me, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(productData['detectedCity'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          Text(productData['description'] ?? 'Sin descripción adicional.', style: const TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 25),
          const Divider(),

          const Text("Contactar al Vendedor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFAF0303),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productData['sellerEmail'] ?? 'Usuario UA', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Text("Vendedor UA verificado", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFAF0303), size: 28),
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  if (currentUser.uid == productData['sellerId']) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este es tu propio producto.")));
                    return;
                  }
                  
                  final sellerId = productData['sellerId'];
                  final sellerName = productData['sellerName'] ?? productData['sellerEmail'] ?? 'Vendedor';
                  final chatRoomId = currentUser.uid.hashCode <= sellerId.hashCode ? '${currentUser.uid}_$sellerId' : '${sellerId}_${currentUser.uid}';
                  
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                  final currentUserName = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['fullName'] ?? 'Usuario' : 'Usuario';
                  
                  await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
                    'participants': [currentUser.uid, sellerId],
                    'users': { currentUser.uid: {'name': currentUserName}, sellerId: {'name': sellerName} },
                    'lastMessageTime': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatRoomId, otherUserId: sellerId, otherUserName: sellerName)));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}