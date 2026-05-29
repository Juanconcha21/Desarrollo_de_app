import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActionLogsScreen extends StatelessWidget {
  const ActionLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logs de Acciones"), backgroundColor: const Color(0xFFAF0303)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('actionLogs').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var log = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              DateTime? date = (log['timestamp'] as Timestamp?)?.toDate();
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFFAF0303)),
                title: Text("${log['moderatorEmail'] ?? 'Desconocido'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("${log['action']}\n${date?.day}/${date?.month}/${date?.year} ${date?.hour}:${date?.minute}"),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}