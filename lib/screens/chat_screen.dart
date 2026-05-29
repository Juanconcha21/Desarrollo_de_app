import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'product_detail_cloud.dart';

/// Pantalla de Chat:
/// Implemento un sistema de mensajería bidireccional apoyado en sub-colecciones de Firestore.
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? productId; // Nuevo: ID del producto asociado al chat
  final String? productTitle; // Nuevo: Título del producto
  final String? productImageUrl; // Nuevo: URL de la imagen del producto

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.productId,
    this.productTitle,
    this.productImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _msgController = TextEditingController();

  /// Orquestación del envío de mensajes:
  /// Realizo una operación de escritura doble: una inserción atómica en la sub-colección 'messages'
  /// y una actualización (merge) en el documento raíz del chat para mantener el 'lastMessage'.
  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final senderFullName = userDoc.exists ? (userDoc.data()?['fullName'] ?? 'Usuario') : 'Usuario';

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    
    await chatRef.collection('messages').add({
      'text': text,
      'senderId': currentUser!.uid,
      'senderName': senderFullName,
      'receiverId': widget.otherUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion([currentUser!.uid, widget.otherUserId]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            // Componente visual para la identidad del interlocutor.
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        backgroundColor: const Color(0xFFAF0303),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.productId != null && widget.productTitle != null)
              _buildProductBanner(), // Muestra el banner del producto si está disponible

            Expanded(
              /// Flujo reactivo de mensajes:
              /// Utilizo un StreamBuilder para escuchar cambios en tiempo real, ordenando por timestamp descendente.
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error al cargar mensajes"));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));

                  final messages = snapshot.data?.docs ?? [];

                  // Estado vacío: feedback visual para el usuario cuando no hay historial.
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waving_hand_rounded, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 15),
                          const Text("¡Saluda para comenzar!", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    // Invierto el orden del ListView para que los mensajes nuevos aparezcan desde el fondo (estilo estándar).
                    reverse: true, 
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == currentUser!.uid;
                      
                      // Parseo y formateo de metadata temporal (Server Timestamps).
                      final Timestamp? timestamp = msg['timestamp'];
                      String timeText = '';
                      if (timestamp != null) {
                        final date = timestamp.toDate();
                        final hour = date.hour.toString().padLeft(2, '0');
                        final minute = date.minute.toString().padLeft(2, '0');
                        timeText = '$hour:$minute';
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFAF0303) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5),
                              bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(timeText, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey.shade400, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Input bar: Gestión de entrada de texto y trigger de envío.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _msgController,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Escribe un mensaje...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Color(0xFFAF0303), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nuevo widget para mostrar el banner del producto
  Widget _buildProductBanner() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(widget.productId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final productData = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              if (widget.productImageUrl != null && widget.productImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.productImageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productTitle ?? 'Producto',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${productData['price'] ?? '0'}',
                      style: const TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DraggableScrollableSheet(
                        initialChildSize: 0.8,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (_, controller) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                          ),
                          child: SingleChildScrollView(
                            controller: controller,
                            child: ProductDetailCloud(
                              productData: productData,
                              productId: widget.productId!,
                              isDarkMode: Theme.of(context).brightness == Brightness.dark,
                              userRole: 'usuario',
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Ver producto", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}
