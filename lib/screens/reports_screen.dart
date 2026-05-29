import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'product_detail_cloud.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AuthService _authService = AuthService();

  Future<void> _handleResolution(String reportId, String productId, String sellerId, bool applySancion) async {
    try {
      if (applySancion) {
        // 1. Aplicar Strike y posible baneo al vendedor
        await _authService.applyStrike(sellerId);
        // 2. Eliminar el producto reportado
        await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      }

      // REGISTRO EN LOGS
      await FirebaseFirestore.instance.collection('actionLogs').add({
        'moderatorEmail': FirebaseAuth.instance.currentUser?.email,
        'action': applySancion ? 'Sancionó y borró producto' : 'Desestimó reporte',
        'targetId': reportId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Marcar el reporte como resuelto
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(applySancion ? "Sanción aplicada y producto eliminado" : "Reporte descartado"),
            backgroundColor: applySancion ? Colors.orange[900] : Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showProductDetails(String productId) async {
    try {
      DocumentSnapshot productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      
      if (!productDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("El producto ya no existe o ha sido eliminado."),
              backgroundColor: Colors.orange[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          );
        }
        return;
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, -5))
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: SingleChildScrollView(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 35),
                              ProductDetailCloud(
                                productData: productData,
                                productId: productId,
                                isDarkMode: isDarkMode,
                                userRole: 'moderador',
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar producto: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Gestión de Reportes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));

          final reports = snapshot.data?.docs ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.3)),
                  const SizedBox(height: 15),
                  const Text("¡Todo en orden!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Text("No hay reportes pendientes de revisión."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index].data() as Map<String, dynamic>;
              final String reportId = reports[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF0F0),
                    child: Icon(Icons.flag, color: Color(0xFFAF0303)),
                  ),
                  title: Text(report['productTitle'] ?? 'Producto Desconocido', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Motivo: ${report['reason']}", style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          _reportDetail("Detalles:", report['details'] ?? 'Sin descripción adicional'),
                          _reportDetail("Reportado por:", report['reporterEmail']),
                          _reportDetail("Fecha:", (report['timestamp'] as Timestamp?)?.toDate().toString() ?? 'N/A'),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              _actionButton(
                                icon: Icons.visibility_outlined,
                                label: "VER PRODUCTO",
                                color: Colors.blue[700]!,
                                onTap: () => _showProductDetails(report['productId']),
                              ),
                              _actionButton(
                                icon: Icons.close,
                                label: "DESCARTAR",
                                color: Colors.grey[600]!,
                                onTap: () => _handleResolution(reportId, report['productId'], report['sellerId'], false),
                              ),
                              _actionButton(
                                icon: Icons.gavel,
                                label: "SANCIONAR",
                                color: const Color(0xFFAF0303),
                                onTap: () => _handleResolution(reportId, report['productId'], report['sellerId'], true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
    );
  }

  Widget _reportDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}