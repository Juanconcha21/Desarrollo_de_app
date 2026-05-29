import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

/// Bandeja de Entrada (Inbox):
/// Centralizo la visualización de todos los hilos de conversación en los que 
/// participa el usuario actual (usando el operador 'arrayContains' en Firestore).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Debes iniciar sesión")));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo limpio
      appBar: AppBar(
        title: const Text("Tus Mensajes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFFAF0303),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Consulta reactiva filtrando por el UID del usuario en el array de participantes.
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
          
          final chats = snapshot.data?.docs.toList() ?? [];

          /// Estrategia de Ordenamiento:
          /// Realizo un sort local para evitar la necesidad de un índice compuesto complejo en Firestore
          /// y para manejar de forma segura los timestamps nulos que ocurren durante la sincronización inicial.
          chats.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1; 
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // UI para estado de bandeja vacía.
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  const Text("Bandeja vacía", style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("No tienes mensajes en este momento.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;

              // Lógica de Negocio: Identificar al "otro" participante del chat.
              final participants = List<String>.from(chatData['participants'] ?? []);
              final otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
              
              // Extraigo metadata del interlocutor desde el mapa 'users' cacheado en el documento del chat.
              final usersMap = chatData['users'] as Map<String, dynamic>? ?? {};
              final otherUserData = usersMap[otherUserId] as Map<String, dynamic>? ?? {};

              final otherUserName = otherUserData['name'] ?? 'Usuario Desconocido';
              final lastMessage = chatData['lastMessage'] ?? '';
              final String? chatProductId = chatData['productId'];
              final String? chatProductTitle = chatData['productTitle'];
              final String? chatProductImageUrl = chatData['productImageUrl'];
              
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId, 
                        otherUserId: otherUserId, 
                        otherUserName: otherUserName,
                        productId: chatProductId,
                        productTitle: chatProductTitle,
                        productImageUrl: chatProductImageUrl,
                      )
                    )
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAF0303).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: Color(0xFFAF0303), size: 26),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            if (chatProductTitle != null && chatProductTitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                                child: Text(
                                  "Producto: $chatProductTitle",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(lastMessage.isEmpty ? "Chat iniciado" : lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}