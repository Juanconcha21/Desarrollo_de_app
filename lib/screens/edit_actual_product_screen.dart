import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditActualProductScreen extends StatefulWidget {
  final DocumentSnapshot product;

  const EditActualProductScreen({super.key, required this.product});

  @override
  State<EditActualProductScreen> createState() => _EditActualProductScreenState();
}

class _EditActualProductScreenState extends State<EditActualProductScreen> {
  late TextEditingController titleController;
  late TextEditingController priceController;
  late TextEditingController descController;
  
  late String selectedSede;
  late String selectedCategory; 
  
  bool isLoading = false;

  final List<String> sedes = ['Sede Talca', 'Sede Temuco', 'Sede Santiago'];
  final List<String> categories = ['Electrodomésticos', 'Tecnología', 'Muebles', 'Hogar', 'Ropa y Accesorios', 'Otros'];

  @override
  void initState() {
    super.initState();
    Map<String, dynamic> data = widget.product.data() as Map<String, dynamic>;
    titleController = TextEditingController(text: data['title']);
    priceController = TextEditingController(text: data['price']);
    descController = TextEditingController(text: data['description']);
    
    selectedSede = data['universitySede'] ?? 'Sede Talca';
    selectedCategory = data['category'] ?? 'Otros'; 
  }

  Future<void> _updateProduct() async {
    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('products').doc(widget.product.id).update({
        'title': titleController.text.trim(),
        'price': priceController.text.trim(),
        'description': descController.text.trim(),
        'universitySede': selectedSede,
        'category': selectedCategory,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Publicación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFAF0303),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(titleController, "Nombre del producto", Icons.shopping_bag_outlined),
            const SizedBox(height: 15),
            _buildInput(priceController, "Precio", Icons.attach_money, isNumber: true),
            const SizedBox(height: 15),
            _buildDropdown(
              value: selectedCategory,
              items: categories,
              icon: Icons.category,
              onChanged: (val) => setState(() => selectedCategory = val!),
            ),
            const SizedBox(height: 15),
            _buildDropdown(
              value: selectedSede,
              items: sedes,
              icon: Icons.location_city,
              onChanged: (val) => setState(() => selectedSede = val!),
            ),
            const SizedBox(height: 15),
            _buildInput(descController, "Descripción", Icons.description_outlined, maxLines: 4),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAF0303),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
  Widget _buildInput(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
  Widget _buildDropdown({required String value, required List<String> items, required IconData icon, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(icon, color: const Color(0xFFAF0303)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}