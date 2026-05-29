import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";

  void _showEditUserDialog(String userId, Map<String, dynamic> data) {
    String selectedRole = data['role'] ?? 'usuario';
    String selectedStatus = data['accountStatus'] ?? 'active';
    int strikes = data['strikes'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Editar: ${data['fullName']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFAF0303))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Rol del Usuario"),
                items: ['usuario', 'moderador', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setStateDialog(() => selectedRole = val!),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: "Estado de Cuenta"),
                items: ['active', 'banned'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setStateDialog(() => selectedStatus = val!),
              ),
              const SizedBox(height: 20),
              const Text("Gestión de Sanciones", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: strikes > 0 ? () => setStateDialog(() => strikes--) : null,
                  ),
                  Text("Strikes: $strikes", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onPressed: () => setStateDialog(() => strikes++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmAndDeleteUser(userId, data['fullName'] ?? 'este usuario');
              },
              child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303)),
              onPressed: () async {
                await _auth.updateUserByAdmin(userId, {
                  'role': selectedRole, 
                  'accountStatus': selectedStatus,
                  'strikes': strikes,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("GUARDAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteUser(String userId, String userName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar usuario?"),
        content: Text("Se borrarán todos los productos y reportes asociados a $userName."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ELIMINAR DEFINITIVAMENTE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        // Usamos un WriteBatch para realizar todas las eliminaciones de forma atómica y eficiente
        WriteBatch batch = _firestore.batch();
        
        var products = await _firestore.collection('products').where('sellerId', isEqualTo: userId).get();
        for (var doc in products.docs) { batch.delete(doc.reference); }
        
        var reports = await _firestore.collection('reports').where('reporterId', isEqualTo: userId).get();
        for (var doc in reports.docs) { batch.delete(doc.reference); }

        batch.delete(_firestore.collection('users').doc(userId));

        await batch.commit();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario eliminado del sistema")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Gestión de Usuarios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o email...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFFAF0303)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _auth.getAllUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
          
          final allUsers = snapshot.data!.docs;
          final users = allUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['fullName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          if (users.isEmpty) return const Center(child: Text("No se encontraron usuarios."));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String uid = users[index].id;
              bool isBanned = userData['accountStatus'] == 'banned';
              int strikes = userData['strikes'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFAF0303),
                    backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null,
                    child: userData['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  title: Text(userData['fullName'] ?? 'Sin nombre', style: TextStyle(fontWeight: FontWeight.bold, color: isBanned ? Colors.red : Colors.black87)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userData['email'] ?? ''),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge(userData['role'] ?? 'usuario', Colors.blue),
                          const SizedBox(width: 8),
                          _badge("Strikes: $strikes", strikes >= 3 ? Colors.red : Colors.orange),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFAF0303)),
                    onPressed: () => _showEditUserDialog(uid, userData),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}