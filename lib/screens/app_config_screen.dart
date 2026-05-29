import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigScreen extends StatelessWidget {
  const AppConfigScreen({super.key});

  void _addItem(BuildContext context, String collection, String label) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Añadir $label"),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: "Nombre de $label")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              await FirebaseFirestore.instance.collection(collection).add({'name': controller.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("AÑADIR"),
          )
        ],
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
                  return ListTile(
                    title: Text(doc['name']),
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