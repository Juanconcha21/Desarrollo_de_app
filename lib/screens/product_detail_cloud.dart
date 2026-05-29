import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'chat_screen.dart'; // 

class ProductDetailCloud extends StatelessWidget {
  final Map<String, dynamic> productData;
  final String productId;
  final bool isDarkMode;
  final String userRole;

  const ProductDetailCloud({
    super.key, 
    required this.productData, 
    required this.productId,
    this.isDarkMode = false,
    this.userRole = 'usuario',
  });

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reportar Producto", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "¿Por qué reportas este producto?",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('reports').add({
                'productId': productId,
                'productTitle': productData['title'],
                'sellerId': productData['sellerId'],
                'reporterId': FirebaseAuth.instance.currentUser?.uid,
                'reason': reasonController.text.trim(),
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'pending',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte enviado al equipo de moderación"), backgroundColor: Colors.orange));
              }
            },
            child: const Text("ENVIAR REPORTE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPending = productData['status'] == 'pending';
    bool isBlocked = productData['status'] == 'blocked';
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPending) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 16, color: Colors.orange), SizedBox(width: 8), Text("ESTE PRODUCTO ESTÁ EN REVISIÓN", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))]),
            ),
          ],
          if (isBlocked) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.block, size: 16, color: Colors.red), SizedBox(width: 8), Text("PUBLICACIÓN BLOQUEADA POR EL ADMIN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))]),
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: productData['imageUrl'] != null && productData['imageUrl'].isNotEmpty
                ? Image.network(productData['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 200, width: double.infinity, color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, color: Colors.grey)), // Fallback si no hay imagen
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(productData['title'] ?? 'Sin título', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor))),
              if (userRole == 'usuario' && productData['sellerId'] != FirebaseAuth.instance.currentUser?.uid)
                IconButton(
                  icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.orange),
                  onPressed: () => _showReportDialog(context),
                  tooltip: "Reportar publicación",
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('\$${productData['price'] ?? '0'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFAF0303))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.school, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(productData['universitySede'] ?? 'Sede Principal', style: TextStyle(color: subTextColor, fontSize: 14)),
              const SizedBox(width: 15),
              const Icon(Icons.near_me, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(productData['detectedCity'] ?? '', style: TextStyle(color: subTextColor, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          Text(productData['description'] ?? 'Sin descripción adicional.', style: TextStyle(fontSize: 15, color: subTextColor)),
          const SizedBox(height: 25),
          const Divider(),

          Text("Contactar al Vendedor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
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
                    Text(productData['sellerEmail'] ?? 'Usuario UA', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    Text("Vendedor UA verificado", style: TextStyle(color: subTextColor, fontSize: 12)),
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
                    'productId': productId,
                    'productTitle': productData['title'],
                    'productImageUrl': productData['imageUrl'],
                    'lastMessageTime': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                      chatId: chatRoomId, 
                      otherUserId: sellerId, 
                      otherUserName: sellerName,
                      productId: productId,
                      productTitle: productData['title'],
                      productImageUrl: productData['imageUrl'],
                    )));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
    );
  }
}