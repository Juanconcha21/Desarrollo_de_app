import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFAF0303)),
            SizedBox(width: 10),
            Text("¿Estás seguro?", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("¿Estás seguro de que deseas borrar esta publicación de forma permanente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete_sweep, color: Colors.white),
                SizedBox(width: 12),
                Text("Producto eliminado correctamente"),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  // FUNCIÓN PARA ACTUALIZAR (UPDATE)
  Future<void> _editProduct(String productId, Map<String, dynamic> data) async {
    final titleController = TextEditingController(text: data['title']?.toString() ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    final descriptionController = TextEditingController(text: data['description']?.toString() ?? '');
    
    String selectedCategory = data['category'] ?? 'Otros';
    String selectedSede = data['universitySede'] ?? 'Sede Talca';
    String currentImageUrl = data['imageUrl'] ?? '';
    
    File? newImageFile;
    final ImagePicker picker = ImagePicker();

    final List<String> categories = ['Electrodomésticos', 'Tecnología', 'Muebles', 'Hogar', 'Ropa y Accesorios', 'Otros'];
    final List<String> sedes = ['Sede Talca', 'Sede Temuco', 'Sede Santiago'];

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Editar Publicación", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gestión de Imagen
                    GestureDetector(
                      onTap: () async {
                        final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                        if (pickedFile != null) {
                          setStateDialog(() => newImageFile = File(pickedFile.path));
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          image: newImageFile != null 
                            ? DecorationImage(image: FileImage(newImageFile!), fit: BoxFit.cover)
                            : (currentImageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(currentImageUrl), fit: BoxFit.cover) : null),
                        ),
                        child: (newImageFile == null && currentImageUrl.isEmpty) 
                          ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                          : Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, size: 20, color: Color(0xFFAF0303)),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Título", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio (\$)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: "Descripción", border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    
                    // Categoría
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 10),
                    
                    // Sede
                    DropdownButtonFormField<String>(
                      value: selectedSede,
                      decoration: const InputDecoration(labelText: "Sede", border: OutlineInputBorder()),
                      items: sedes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedSede = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text("CANCELAR")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303)),
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    try {
                      String finalImageUrl = currentImageUrl;

                      // Si se seleccionó una nueva imagen, subirla
                      if (newImageFile != null) {
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('product_images')
                            .child('${DateTime.now().millisecondsSinceEpoch}_${currentUser!.uid}.jpg');
                        await storageRef.putFile(newImageFile!);
                        finalImageUrl = await storageRef.getDownloadURL();
                      }

                      // Actualizar Firestore
                      await FirebaseFirestore.instance.collection('products').doc(productId).update({
                        'title': titleController.text.trim(),
                        'price': priceController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'category': selectedCategory,
                        'universitySede': selectedSede,
                        'imageUrl': finalImageUrl,
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text("¡Publicación actualizada con éxito!"),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.all(20),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(child: Text("Error: $e")),
                              ],
                            ),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.all(20),
                          ),
                        );
                      }
                    } finally {
                      setStateDialog(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("GUARDAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
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
            final aTime = aData['createdAt'] is Timestamp ? aData['createdAt'] as Timestamp : null;
            final bTime = bData['createdAt'] is Timestamp ? bData['createdAt'] as Timestamp : null;
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
              final String title = data['title']?.toString() ?? 'Sin título';
              final String price = data['price']?.toString() ?? '0';

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
                        child: data['imageUrl'] != null && data['imageUrl'] is String && data['imageUrl'].isNotEmpty
                            ? Image.network(data['imageUrl'], width: 80, height: 80, fit: BoxFit.cover)
                            : Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                      ),
                      const SizedBox(width: 15),
                      
                      // Detalles del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isSold ? TextDecoration.lineThrough : null)),
                            const SizedBox(height: 5),
                            Text('\$$price', style: const TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
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
                                _editProduct(productId, data);
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