import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedSede = 'Sede Talca';
  final List<String> sedes = ['Sede Talca', 'Sede Temuco', 'Sede Santiago'];

  String selectedCategory = 'Tecnología';
  final List<String> categories = ['Electrodomésticos', 'Tecnología', 'Muebles', 'Hogar', 'Ropa y Accesorios', 'Otros'];

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, selecciona una foto del producto")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "No hay sesión iniciada";

      // Se ha eliminado la geolocalización y la subida de imagen a Firebase Storage.
      // La imagen no será visible para otros usuarios.
      
      String sellerName = "Usuario";
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        sellerName = userData['fullName'] ?? "Usuario";
      }

      // Se crea el documento en Firestore con los datos del producto.
      await FirebaseFirestore.instance.collection('products').add({
        'title': nameController.text.trim(),
        'price': priceController.text.trim(),
        'description': descriptionController.text.trim(),
        'universitySede': selectedSede,
        'category': selectedCategory,
        // 'detectedCity' ha sido eliminado.
        'imageUrl': '', // URL vacía porque la imagen es solo local.
        'sellerId': user.uid,
        'sellerEmail': user.email,
        'sellerName': sellerName, 
        
        'isSold': false, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Producto publicado con éxito!"), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al publicar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo un poco más limpio y brillante
      appBar: AppBar(
        title: const Text("Publicar Producto", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFFAF0303),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Efecto de rebote moderno al scrollear
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. SELECTOR DE FOTO MEJORADO
              // ==========================================
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0xFFAF0303).withOpacity(0.2), width: 2),
                    image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFAF0303).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: _image == null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: const Color(0xFFAF0303).withOpacity(0.08), shape: BoxShape.circle),
                            child: const Icon(Icons.add_photo_alternate_rounded, size: 45, color: Color(0xFFAF0303)), // Icono de añadir foto
                          ),
                          const SizedBox(height: 15),
                          const Text("Sube una foto atractiva", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text("¡Los productos con foto se venden más rápido!", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            right: 15,
                            top: 15,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded, color: Color(0xFFAF0303), size: 20), // Icono de editar
                            ), // Icono de editar
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 35),

              // ==========================================
              // 2. FORMULARIO CON DISEÑO MODERNO (SOMBRAS Y BORDES)
              // ==========================================
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFAF0303)),
                  SizedBox(width: 10),
                  Text("Detalles del Producto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 20),

              _buildTextField(controller: nameController, label: "¿Qué estás vendiendo?", icon: Icons.sell_outlined, validator: (v) => v!.isEmpty ? "Falta el título" : null),
              const SizedBox(height: 15),
              
              _buildTextField(controller: priceController, label: "Precio (\$) - Ej: 15000", icon: Icons.payments_outlined, isNumber: true, validator: (v) => v!.isEmpty ? "Falta el precio" : null),
              const SizedBox(height: 15),

              _buildDropdown(
                value: selectedCategory,
                icon: Icons.category_outlined,
                items: categories,
                onChanged: (newValue) => setState(() => selectedCategory = newValue!),
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                value: selectedSede,
                icon: Icons.location_on_outlined,
                items: sedes,
                onChanged: (newValue) => setState(() => selectedSede = newValue!),
              ),
              const SizedBox(height: 15),

              // CAMPO DE DESCRIPCIÓN MÁS AMPLIO
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(20), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
                ),
                child: TextFormField(
                  controller: descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "Añade una descripción (estado, detalles extras, etc.)",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 85), // Alinea el ícono arriba
                      child: Icon(Icons.description_outlined, color: Color(0xFFAF0303)),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ==========================================
              // 3. BOTÓN PUBLICAR POTENCIADO
              // ==========================================
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFAF0303).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _uploadProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAF0303),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text("PUBLICAR AHORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // WIDGETS REUTILIZABLES PARA EL FORMULARIO
  // =================================================================

  Widget _buildDropdown({required String value, required IconData icon, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: items.map((String item) {
            return DropdownMenuItem(
              value: item, 
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFAF0303), size: 22),
                  const SizedBox(width: 15),
                  Text(item, style: const TextStyle(color: Colors.black87)),
                ],
              )
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false, required String? Function(String?) validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
}