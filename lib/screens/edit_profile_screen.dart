import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';

/// Pantalla de Gestión de Perfil:
/// Manejo la actualización de datos personales y la lógica de carga de avatares (binarios).
class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentCareer;
  final String currentDob;
  final String? currentPhotoUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentCareer,
    required this.currentDob,
    this.currentPhotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final authService = AuthService();
  late TextEditingController nameController;
  late TextEditingController careerController;
  late TextEditingController dobController;
  File? _image;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentName);
    careerController = TextEditingController(text: widget.currentCareer);
    dobController = TextEditingController(text: widget.currentDob);
  }

  /// Gestión de Media: Captura de imagen desde galería con compresión del 50%.
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  /// Workflow de Guardado: 
  /// Orquesto la subida de la imagen (si existe) y la actualización de los documentos en Firestore.
  Future<void> _saveProfile() async {
    if (nameController.text.trim().isEmpty) return;

    setState(() => isLoading = true);
    try {
      String? newPhotoUrl;
      if (_image != null) {
        newPhotoUrl = await authService.uploadProfilePicture(_image!.path);
      }

      // Actualizamos los datos en Firestore a través del servicio
      await authService.updateProfile(
        name: nameController.text.trim(),
        career: careerController.text.trim(),
        dob: dobController.text.trim(),
        photoUrl: newPhotoUrl,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // Componente de avatar interactivo.
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    // Lógica de visualización jerárquica: Imagen local nueva > Imagen remota > Icono default.
                    backgroundImage: _image != null
                        ? FileImage(_image!) // Si hay una nueva imagen seleccionada localmente
                        : (widget.currentPhotoUrl != null && widget.currentPhotoUrl!.startsWith('http')
                            ? NetworkImage(widget.currentPhotoUrl!) // Si es una URL de Firebase Storage
                            : (widget.currentPhotoUrl != null ? FileImage(File(widget.currentPhotoUrl!)) : null) // Si es una ruta local antigua (para compatibilidad)
                          ) as ImageProvider?,
                    child: _image == null && widget.currentPhotoUrl == null 
                        ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFAF0303), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildEditField(nameController, "Nombre Completo", Icons.person_outline),
            const SizedBox(height: 15),
            _buildEditField(careerController, "Carrera", Icons.school_outlined),
            const SizedBox(height: 15),
            _buildDateField(dobController, "Fecha de Nacimiento", Icons.cake_outlined, context),

            const SizedBox(height: 40),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAF0303),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, IconData icon, BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xFFAF0303), onPrimary: Colors.white, onSurface: Colors.black),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
          });
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}