import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigScreen extends StatelessWidget {
  const AppConfigScreen({super.key});

  /// Mapeo automático de estilos basado en palabras clave.
  /// Mantiene la consistencia visual con el resto de la aplicación.
  Map<String, dynamic> _getCategoryStyle(String title) {
    final name = title.toLowerCase();
    if (name.contains('electro')) return {'icon': Icons.kitchen, 'color': Colors.blueGrey};
    if (name.contains('tecno') || name.contains('comput')) return {'icon': Icons.computer, 'color': Colors.blue};
    if (name.contains('mueble')) return {'icon': Icons.chair, 'color': Colors.brown};
    if (name.contains('hogar') || name.contains('casa')) return {'icon': Icons.home, 'color': Colors.green};
    if (name.contains('ropa') || name.contains('moda')) return {'icon': Icons.checkroom, 'color': Colors.red};
    if (name.contains('libro') || name.contains('estudio')) return {'icon': Icons.menu_book_rounded, 'color': Colors.orange};
    if (name.contains('deporte')) return {'icon': Icons.sports_soccer_rounded, 'color': Colors.indigo};
    
    return {'icon': Icons.category_rounded, 'color': Colors.teal}; // Estilo por defecto
  }

  void _addItem(BuildContext context, String collection, String label) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final style = _getCategoryStyle(controller.text);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Text("Nueva $label", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFAF0303))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (collection == "categories") ...[
                  const Text("Vista previa del sistema:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (style['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(style['icon'] as IconData, color: style['color'] as Color, size: 45),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: controller,
                  onChanged: (val) => setStateDialog(() {}),
                  decoration: InputDecoration(
                    hintText: "Nombre de la $label",
                    prefixIcon: Icon(collection == "categories" ? style['icon'] as IconData : Icons.location_on, color: const Color(0xFFAF0303)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAF0303),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection(collection).add({'name': controller.text.trim()});
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Gestor de Aplicación"),
          backgroundColor: const Color(0xFFAF0303),
          bottom: const TabBar(tabs: [Tab(text: "Categorías"), Tab(text: "Sedes")]),
        ),
        body: TabBarView(
          children: [
            _configList("categories", "Categoría", context),
            _configList("universitySedes", "Sede", context),
          ],
        ),
      ),
    );
  }

  Widget _configList(String collection, String label, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text("Añadir nueva $label"),
            onPressed: () => _addItem(context, collection, label),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(collection).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  final title = doc['name'];
                  final style = collection == "categories" ? _getCategoryStyle(title) : null;

                  return ListTile(
                    leading: style != null 
                      ? CircleAvatar(
                          backgroundColor: (style['color'] as Color).withOpacity(0.1),
                          child: Icon(style['icon'] as IconData, color: style['color'] as Color, size: 20),
                        )
                      : const Icon(Icons.location_on, color: Color(0xFFAF0303)),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => doc.reference.delete(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}