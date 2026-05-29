import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("Dashboard Administrativo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Métricas en Tiempo Real", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            
            _buildMetricsGrid(isTablet),
            
            const SizedBox(height: 32),
            
            const Text("Análisis de Inventario Real", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            
            _buildRealTimeCharts(),
            
            const SizedBox(height: 32),
            
            const Text("Actividad Reciente", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            
            _buildRecentActivityList(),
            
            const SizedBox(height: 32),
            
            const Text("Estado de Servicios del Sistema", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            
            _buildSystemStatus(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isTablet) {
    return GridView.count(
      crossAxisCount: isTablet ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard("Usuarios", "users", Icons.people_rounded, Colors.blue),
        _buildMetricCard("Productos", "products", Icons.shopping_bag_rounded, Colors.green),
        _buildMetricCard("Reportes", "reports", Icons.flag_rounded, Colors.orange),
        _buildMetricCard("Chats", "chats", Icons.message_rounded, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Icon(Icons.error_outline, color: Colors.red));
        
        String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "0";
        bool isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: 12),
              isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealTimeCharts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
        
        final docs = snapshot.data!.docs;
        final Map<String, int> counts = {
          'Electrodomésticos': 0,
          'Tecnología': 0,
          'Muebles': 0,
          'Hogar': 0,
          'Ropa y Accesorios': 0,
          'Otros': 0,
        };

        for (var doc in docs) {
          final cat = (doc.data() as Map<String, dynamic>)['category'] ?? 'Otros';
          if (counts.containsKey(cat)) {
            counts[cat] = counts[cat]! + 1;
          } else {
            counts['Otros'] = counts['Otros']! + 1;
          }
        }

        return Container(
          height: 380,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
          child: Column(
            children: [
              const SizedBox(height: 15),
              const Text("Desliza para ver: Cantidad vs Porcentaje", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Expanded(
                child: PageView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildBarChart(counts),
                    _buildPieChart(counts),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarChart(Map<String, int> data) {
    final titles = data.keys.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (data.values.fold(0, (max, v) => v > max ? v : max).toDouble() + 1),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= titles.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(titles[value.toInt()].length > 4 ? titles[value.toInt()].substring(0, 4) : titles[value.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: titles.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: data[e.value]!.toDouble(), color: _getCategoryColor(e.value), width: 16, borderRadius: BorderRadius.circular(4))])).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    int total = data.values.fold(0, (sum, v) => sum + v);
    if (total == 0) return const Center(child: Text("Sin productos registrados"));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: data.entries.where((e) => e.value > 0).map((e) {
            final percentage = (e.value / total * 100).toStringAsFixed(1);
            return PieChartSectionData(
              color: _getCategoryColor(e.key),
              value: e.value.toDouble(),
              title: '$percentage%',
              radius: 65,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Electrodomésticos': return Colors.blueGrey;
      case 'Tecnología': return Colors.blue;
      case 'Muebles': return Colors.brown;
      case 'Hogar': return Colors.green;
      case 'Ropa y Accesorios': return Colors.red;
      default: return Colors.teal;
    }
  }

  Widget _buildRecentActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar actividad"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
        
        final docs = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFAF0303), child: Icon(Icons.add_shopping_cart, color: Colors.white, size: 18)),
                title: Text(data['title'] ?? 'Nuevo Producto', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text("Vendedor: ${data['sellerName'] ?? 'Anon'}", style: const TextStyle(fontSize: 12)),
                trailing: Text("\$${data['price']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSystemStatus() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatusChip("Firestore DB", true),
        _buildStatusChip("Auth Service", true),
        _buildStatusChip("Cloud Storage", true),
        _buildStatusChip("Push Notifications", false),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.orange, shape: BoxShape.circle)), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))]),
    );
  }
}