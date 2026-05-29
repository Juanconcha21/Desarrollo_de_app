import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Importar Firebase Storage
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';

/// Pantalla de Publicación: 
/// Implementa la lógica de ingesta de datos, geolocalización y carga de binarios (imágenes).
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

  // Domain-specific data para el catálogo.
  String selectedCategory = 'Tecnología';
  final List<String> categories = ['Electrodomésticos', 'Tecnología', 'Muebles', 'Hogar', 'Ropa y Accesorios', 'Otros'];

  LatLng? _pickedLocation;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false; // Flag para manejar el estado de carga del proceso asíncrono

  /// Captura de coordenadas GPS:
  /// Uso el paquete Geolocator para obtener la ubicación exacta del vendedor, mejorando el UX en el mapa.
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _pickedLocation = LatLng(position.latitude, position.longitude);
    });
  }

  /// Selector de imágenes:
  /// Integro ImagePicker para obtener fotos de la galería con compresión de calidad (50%) para optimizar bandwidth.
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  /// Workflow de Publicación:
  /// 1. Validación de Formulario. 2. Upload de Imagen a Firebase Storage. 
  /// 3. Inserción del documento en Firestore con la URL de descarga y metadata del vendedor.
  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, activa tu ubicación para publicar"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.add_a_photo, color: Colors.white),
              SizedBox(width: 12),
              Text("Por favor, selecciona una foto del producto"),
            ],
          ),
          backgroundColor: const Color(0xFFAF0303),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "No hay sesión iniciada";

      // Fase 1: Persistencia de Binarios (Image Storage)
      String? imageUrl;
      if (_image != null) {
        final storageRef = FirebaseStorage.instance.ref().child('product_images').child('${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg');
        final uploadTask = storageRef.putFile(_image!);
        final snapshot = await uploadTask.whenComplete(() {});
        imageUrl = await snapshot.ref.getDownloadURL();
      }
      
      String sellerName = "Usuario";
      // Obtener el nombre completo del vendedor
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        sellerName = userData['fullName'] ?? "Usuario";
      }

      // Fase 2: Persistencia Documental (Firestore)
      await FirebaseFirestore.instance.collection('products').add({
        'title': nameController.text.trim(),
        'price': priceController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': selectedCategory,
        'location': GeoPoint(_pickedLocation!.latitude, _pickedLocation!.longitude),
        'imageUrl': imageUrl ?? '', // Guardar la URL de la imagen subida
        'sellerId': user.uid,
        'sellerEmail': user.email,
        'sellerName': sellerName, 
        
        'isSold': false, 
        'status': 'pending', // Nuevo: Esperando aprobación del moderador
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.white),
                SizedBox(width: 12),
                Text("¡Producto enviado a revisión!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(20),
          ),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("Error al publicar: $e")),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        ),
      );
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
              // Componente visual para la captura de media.
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
              // Capa de captura de datos con validación en tiempo de ejecución.
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

              // Integración con Google Maps API para mostrar el punto de venta.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, color: Color(0xFFAF0303)),
                        const SizedBox(width: 10),
                        const Text("Ubicación de venta", style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(onPressed: _getCurrentLocation, child: const Text("Obtener")),
                      ],
                    ),
                    if (_pickedLocation != null)
                      SizedBox(
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(target: _pickedLocation!, zoom: 15),
                            markers: {Marker(markerId: const MarkerId("selected"), position: _pickedLocation!)},
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      )
                    else
                      const Text("Selecciona tu ubicación actual para que te encuentren", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
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
              // 3. BOTÓN PUBLICAR 
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