import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementManagerScreen extends StatefulWidget {
  const AnnouncementManagerScreen({super.key});

  @override
  State<AnnouncementManagerScreen> createState() => _AnnouncementManagerScreenState();
}

class _AnnouncementManagerScreenState extends State<AnnouncementManagerScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isActive = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentAnnouncement();
  }

  Future<void> _loadCurrentAnnouncement() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('announcement')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _messageController.text = data['message'] ?? '';
          _isActive = data['isActive'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar anuncio: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAnnouncement() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('announcement')
          .set({
        'message': _messageController.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Anuncio actualizado correctamente"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Sistema de Anuncios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Configurar Banner Global", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Este mensaje aparecerá en la parte superior del Home para todos los usuarios.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: "Mensaje del anuncio",
                      hintText: "Ej: Mantenimiento programado para este domingo...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text("Mostrar anuncio", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Activa o desactiva la visibilidad del banner"),
                    value: _isActive,
                    activeColor: const Color(0xFFAF0303),
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAF0303),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _saveAnnouncement,
                      child: const Text("GUARDAR ANUNCIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}