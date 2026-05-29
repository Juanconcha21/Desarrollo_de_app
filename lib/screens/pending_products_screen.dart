import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_detail_cloud.dart';

class PendingProductsScreen extends StatelessWidget {
  const PendingProductsScreen({super.key});

  Future<void> _updateProductStatus(BuildContext modalContext, BuildContext screenContext, String productId, String status, Function(bool) setProcessing) async {
    try {
      setProcessing(true);
      
      final messenger = ScaffoldMessenger.of(screenContext);

      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'status': status});
      
      // REGISTRO EN LOGS
      await FirebaseFirestore.instance.collection('actionLogs').add({
        'moderatorEmail': FirebaseAuth.instance.currentUser?.email,
        'action': status == 'approved' ? 'Aprobó producto' : 'Rechazó producto',
        'targetId': productId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (modalContext.mounted) {
        Navigator.pop(modalContext);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(status == 'approved' ? Icons.check_circle : Icons.cancel, color: Colors.white),
                const SizedBox(width: 10),
                Text(status == 'approved' ? "Producto aprobado y publicado" : "Producto rechazado"),
              ],
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setProcessing(false);
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  void _showModerationDetail(BuildContext screenContext, Map<String, dynamic> product, String productId) {
    bool isProcessing = false;
    final bool isDarkMode = Theme.of(screenContext).brightness == Brightness.dark;

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
          builder: (modalContext, setStateDialog) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                height: MediaQuery.of(modalContext).size.height * 0.8,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                        child: Column(
                          children: [
                            ProductDetailCloud(
                              productData: product,
                              productId: productId,
                              isDarkMode: isDarkMode,
                              userRole: 'moderador',
                            ),
                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                            border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey.shade100)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)) : const Icon(Icons.close, size: 18),
                                  onPressed: isProcessing ? null : () => _updateProductStatus(modalContext, screenContext, productId, 'rejected', (val) => setStateDialog(() => isProcessing = val)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  label: Text(isProcessing ? "ESPERE..." : "RECHAZAR", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 18, color: Colors.white),
                                  onPressed: isProcessing ? null : () => _updateProductStatus(modalContext, screenContext, productId, 'approved', (val) => setStateDialog(() => isProcessing = val)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  label: Text(isProcessing ? "ESPERE..." : "APROBAR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aprobaciones Pendientes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("¡Todo al día!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Text("No hay productos pendientes de revisión."),
                ],
              ),
            );
          }

          final products = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return GestureDetector(
                onTap: () => _showModerationDetail(context, data, doc.id),
                child: _buildPendingCard(data, isDarkMode), // ✅ FIX 2: faltaba pasar isDarkMode
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> product, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                      ? Image.network(product['imageUrl'], fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: const Text("PENDIENTE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title'] ?? 'Sin título',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product['sellerName'] ?? 'Usuario',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAF0303).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text("REVISAR", style: TextStyle(color: Color(0xFFAF0303), fontSize: 12, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}