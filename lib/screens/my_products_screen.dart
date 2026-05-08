import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // FUNCIÓN PARA ELIMINAR (DELETE)
  Future<void> _deleteProduct(String productId) async {
    // Nube de confirmación antes de borrar
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Producto", style: TextStyle(color: Color(0xFFAF0303))),
        content: const Text("¿Estás seguro de que deseas borrar esta publicación de forma permanente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado"), backgroundColor: Colors.red));
      }
    }
  }

  // FUNCIÓN PARA ACTUALIZAR (UPDATE)
  Future<void> _editProduct(String productId, String currentTitle, String currentPrice) async {
    TextEditingController titleController = TextEditingController(text: currentTitle);
    TextEditingController priceController = TextEditingController(text: currentPrice);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Producto", style: TextStyle(color: Color(0xFFAF0303))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Título del producto")),
            const SizedBox(height: 10),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio (\$)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303)),
            onPressed: () async {
              // Actualizamos en Firebase
              await FirebaseFirestore.instance.collection('products').doc(productId).update({
                'title': titleController.text.trim(),
                'price': priceController.text.trim(),
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto actualizado"), backgroundColor: Colors.green));
              }
            },
            child: const Text("GUARDAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // FUNCIÓN PARA MARCAR COMO VENDIDO (UPDATE)
  Future<void> _toggleSoldStatus(String productId, bool isCurrentlySold) async {
    await FirebaseFirestore.instance.collection('products').doc(productId).update({
      'isSold': !isCurrentlySold,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Debes iniciar sesión")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Productos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // LEER (READ): Filtramos solo los productos del usuario actual
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aún no has publicado ningún producto."));
          }

          // Ordenamos los productos localmente para evitar el error de "Índice compuesto faltante" en Firebase
          final products = snapshot.data!.docs.toList();
          products.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return -1; // Los recién creados (aún sin sync) van primero
            if (bTime == null) return 1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final data = doc.data() as Map<String, dynamic>;
              final String productId = doc.id;
              final bool isSold = data['isSold'] ?? false;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // Imagen del producto
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                            ? Image.network(data['imageUrl'], width: 80, height: 80, fit: BoxFit.cover)
                            : Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                      ),
                      const SizedBox(width: 15),
                      
                      // Detalles del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['title'] ?? 'Sin título', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isSold ? TextDecoration.lineThrough : null)),
                            const SizedBox(height: 5),
                            Text('\$${data['price'] ?? '0'}', style: const TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(isSold ? "VENDIDO" : "DISPONIBLE", style: TextStyle(color: isSold ? Colors.grey : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      
                      // Botones de Acción (Update y Delete)
                      Column(
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editProduct(productId, data['title'] ?? '', data['price'] ?? '');
                              } else if (value == 'delete') {
                                _deleteProduct(productId);
                              } else if (value == 'toggleSold') {
                                _toggleSoldStatus(productId, isSold);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text('Editar')])),
                              PopupMenuItem(value: 'toggleSold', child: Row(children: [Icon(isSold ? Icons.check_circle_outline : Icons.sell, color: Colors.green), const SizedBox(width: 10), Text(isSold ? 'Marcar disponible' : 'Marcar vendido')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 10), Text('Eliminar')])),
                            ],
                          ),
                        ],
                      )
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