import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_profile_screen.dart';
import 'publish_screen.dart';
import 'product_detail_cloud.dart';
import 'my_products_screen.dart';
import 'inbox_screen.dart'; //
import 'login_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final auth = AuthService();
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 1;
  bool isDarkMode = false;
  String userName = "Cargando...";
  String userCareer = "Cargando...";
  String userDob = "Cargando...";
  String? profileImageUrl;
  String? selectedFilterCategory;
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    }
  }
  Future<void> _loadUserData() async {
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            userName = data['fullName'] ?? 'Usuario';
            userCareer = data['career'] ?? 'No especificada';
            userDob = data['dob'] ?? 'No especificada';
            profileImageUrl = data['photoUrl'] != null && data['photoUrl'].isNotEmpty
                ? data['photoUrl']
                : null;
          });
        }
      } catch (e) {
        print("Error cargando perfil: $e");
      }
    }
  }

  Future<void> _signOut() async {
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final surfaceColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final mutedTextColor = isDarkMode ? Colors.white54 : Colors.grey;

    final List<Widget> screens = [
      _buildCategoriesTab(surfaceColor, textColor),
      _buildForYouTab(surfaceColor, textColor, mutedTextColor),
      _buildProfileTab(surfaceColor, textColor, mutedTextColor),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _selectedIndex, children: screens),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: const Color(0xFFAF0303),
              unselectedItemColor: isDarkMode
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.grid_view_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.grid_view_rounded, size: 28),
                  ),
                  label: 'Categorías',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.star_border_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.star_rounded, size: 30),
                  ),
                  label: 'Para ti',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded, size: 28),
                  ),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PublishScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFFAF0303),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Publicar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }


  /// 1. PESTAÑA: CATEGORÍAS 

  Widget _buildCategoriesTab(Color surfaceColor, Color textColor) {
    final List<Map<String, dynamic>> gridCategories = [
      {
        'title': 'Electrodomésticos',
        'icon': Icons.kitchen,
        'color': Colors.blueGrey,
      },
      {'title': 'Tecnología', 'icon': Icons.computer, 'color': Colors.blue},
      {'title': 'Muebles', 'icon': Icons.chair, 'color': Colors.brown},
      {'title': 'Hogar', 'icon': Icons.home, 'color': Colors.green},
      {
        'title': 'Ropa y Accesorios',
        'icon': Icons.checkroom,
        'color': Colors.red,
      },
      {'title': 'Otros', 'icon': Icons.category, 'color': Colors.teal},
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Explorar\nCategorías',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: gridCategories.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedFilterCategory = gridCategories[index]['title'];
                      _selectedIndex = 1;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDarkMode ? 0.3 : 0.03,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: gridCategories[index]['color'].withOpacity(
                              isDarkMode ? 0.2 : 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            gridCategories[index]['icon'],
                            color: gridCategories[index]['color'],
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          gridCategories[index]['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  /// 2. PESTAÑA: PARA TI 

  Widget _buildForYouTab(
    Color surfaceColor,
    Color textColor,
    Color mutedTextColor,
  ) {
    Query productsQuery = FirebaseFirestore.instance.collection('products');

    if (selectedFilterCategory != null) {
      productsQuery = productsQuery.where(
        'category',
        isEqualTo: selectedFilterCategory,
      );
    } else {
      productsQuery = productsQuery.orderBy('createdAt', descending: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 50,
            left: 20,
            right: 10,
            bottom: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFAF0303),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hola,',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {},
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const InboxScreen(),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 8,
                                minHeight: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: mutedTextColor),
                    hintText: 'Buscar en tu comunidad...',
                    hintStyle: TextStyle(color: mutedTextColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (selectedFilterCategory != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.filter_list,
                      size: 18,
                      color: Color(0xFFAF0303),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Mostrando: $selectedFilterCategory",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => selectedFilterCategory = null),
                  child: const Text(
                    "Ver todos",
                    style: TextStyle(
                      color: Color(0xFFAF0303),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: productsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFAF0303)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 80,
                        color: isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        selectedFilterCategory != null
                            ? 'No hay productos en esta categoría'
                            : 'Aún no hay productos publicados.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final products = snapshot.data!.docs;

              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.70,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final productData =
                      products[index].data() as Map<String, dynamic>;

                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            ProductDetailCloud(productData: productData),
                      );
                    },
                    child: _buildProductCard(
                      productData,
                      surfaceColor,
                      textColor,
                      mutedTextColor,
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

  Widget _buildProductCard(
    Map<String, dynamic> product,
    Color surfaceColor,
    Color textColor,
    Color mutedTextColor,
  ) {
    bool isSold = product['isSold'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          product['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                        if (isSold)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: const Center(
                              child: Text(
                                "VENDIDO",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSold ? mutedTextColor : textColor,
                    fontSize: 14,
                    decoration: isSold ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${product['price'] ?? '0'}',
                  style: TextStyle(
                    color: isSold ? Colors.grey : const Color(0xFFAF0303),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      product['detectedCity'] ?? 'Sede UA',
                      style: TextStyle(color: mutedTextColor, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildProfileTab(
    Color surfaceColor,
    Color textColor,
    Color mutedTextColor,
  ) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: IconButton(
                icon: Icon(Icons.edit_note, color: textColor, size: 32),
                tooltip: "Editar Perfil",
                onPressed: () async {
                  // Esperamos a que el usuario termine de editar
                  bool? updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        currentName: userName,
                        currentCareer: userCareer,
                        currentDob: userDob,
                        currentPhotoUrl: profileImageUrl,
                      ),
                    ),
                  );

                  // Si guardó los cambios, recargamos los datos del usuario
                  if (updated == true) {
                    _loadUserData();
                  }
                },
              ),
            ),
          ),

          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFAF0303),
            backgroundImage: profileImageUrl != null && profileImageUrl!.startsWith('http')
                ? NetworkImage(profileImageUrl!)
                : null,
            child: profileImageUrl == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 15),

          Text(
            userName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? '',
            style: TextStyle(color: mutedTextColor, fontSize: 14),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoChip(Icons.book, userCareer, textColor),
              const SizedBox(width: 10),
              _infoChip(Icons.cake, userDob, textColor),
            ],
          ),
          const SizedBox(height: 25),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15, bottom: 10),
                    child: Text(
                      "Tu Cuenta",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: mutedTextColor,
                      ),
                    ),
                  ),

                  _profileOptionTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Mis Productos Publicados',
                    textColor: textColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyProductsScreen(),
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.only(
                      left: 15,
                      top: 20,
                      bottom: 10,
                    ),
                    child: Text(
                      "Ajustes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: mutedTextColor,
                      ),
                    ),
                  ),

                  SwitchListTile(
                    title: Text(
                      'Modo Oscuro',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.dark_mode_outlined, color: textColor),
                    ),
                    value: isDarkMode,
                    activeColor: const Color(0xFFAF0303),
                    onChanged: (value) async {
                      setState(() => isDarkMode = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', value);
                    },
                  ),

                  _profileOptionTile(
                    icon: Icons.lock_reset,
                    title: 'Cambiar contraseña',
                    textColor: textColor,
                    onTap: _showChangePasswordDialog,
                  ),
                  _profileOptionTile(
                    icon: Icons.help_outline,
                    title: 'Centro de ayuda',
                    textColor: textColor,
                    onTap: _showHelpCenterDialog,
                  ),

                  const Divider(height: 40),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout, color: Colors.red),
                    ),
                    title: const Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFAF0303)),
                                SizedBox(width: 10),
                                Text("Cerrar Sesión", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: const Text("¿Estás seguro de que deseas cerrar sesión en Marketplace UA?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(), // Solo cierra la nube
                                child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop(); 
                                  await _signOut();
                                  if (context.mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false, // Elimina el historial de navegación para que no puedan volver atrás
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFAF0303),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text("SÍ, SALIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isChanging = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Color(0xFFAF0303)),
                  SizedBox(width: 10),
                  Text("Cambiar Contraseña", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Para proteger tu cuenta, por favor ingresa tu contraseña actual antes de elegir una nueva."),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: "Contraseña Actual",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setStateDialog(() => obscureCurrent = !obscureCurrent),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) => val!.isEmpty ? "Campo requerido" : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: "Nueva Contraseña",
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Campo requerido";
                          String pattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$';
                          RegExp regex = RegExp(pattern);
                          if (!regex.hasMatch(val)) {
                            return "8+ caracteres, mayús, minús, nro y símbolo.";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Confirmar Nueva Contraseña",
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) {
                          if (val != newPasswordController.text) return "Las contraseñas no coinciden";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isChanging ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setStateDialog(() => isChanging = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) throw "No se pudo encontrar el usuario.";
                        AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: currentPasswordController.text.trim());
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newPasswordController.text.trim());
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contraseña actualizada con éxito"), backgroundColor: Colors.green));
                        }
                      } on FirebaseAuthException catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.getSpanishErrorMessage(e)), backgroundColor: Colors.red));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      } finally {
                        if (mounted) setStateDialog(() => isChanging = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: isChanging ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text("GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHelpCenterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.help_outline, color: Color(0xFFAF0303)), SizedBox(width: 10), Text("Centro de Ayuda", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold))]),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          buttonPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
          alignment: Alignment.center,
          content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [_buildHelpTile("¿Cómo publico un producto?", "Ve a la pestaña 'Para ti', presiona el botón rojo 'Publicar', completa el formulario con los detalles de tu producto, sube una foto y presiona 'Publicar Ahora'."), _buildHelpTile("¿Cómo contacto a un vendedor?", "Al ver un producto que te interesa, tócalo para ver los detalles. En la parte inferior, verás la información del vendedor y un ícono de chat para iniciar una conversación."), _buildHelpTile("¿Puedo editar o eliminar mis publicaciones?", "Sí. En la pestaña 'Perfil', selecciona 'Mis Productos Publicados'. Verás una lista de tus artículos. Cada uno tiene un menú (tres puntos) con opciones para editar, eliminar o marcar como vendido."), _buildHelpTile("¿Es seguro comprar aquí?", "Marketplace UA es una plataforma para la comunidad. Te recomendamos siempre encontrarte en lugares públicos y seguros dentro del campus para realizar intercambios. Nunca compartas información personal sensible.")])),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("CERRAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () { Navigator.of(context).pop(); _showContactFormDialog(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text("ENVIAR MENSAJE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildHelpTile(String title, String content) {
    return ExpansionTile(
      iconColor: const Color(0xFFAF0303),
      collapsedIconColor: Colors.grey,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), child: Text(content, style: TextStyle(color: Colors.grey[600], height: 1.4)))],
    );
  }

  Widget _profileOptionTile({
    required IconData icon,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: textColor),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDarkMode ? Colors.white54 : Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showContactFormDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: userName);
    final emailController = TextEditingController(text: user?.email);
    final messageController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.mail_outline, color: Color(0xFFAF0303)),
                  SizedBox(width: 10),
                  Text("Contáctanos", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Envíanos tus dudas o sugerencias. Te responderemos a la brevedad.", textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Tu Nombre",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) => val!.isEmpty ? "Campo requerido" : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Tu Correo Electrónico",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) {
                          if (val!.isEmpty) return "Campo requerido";
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return "Correo inválido";
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: "Tu Mensaje",
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 80),
                            child: Icon(Icons.message_outlined),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (val) => val!.isEmpty ? "Campo requerido" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setStateDialog(() => isSending = true);
                      // Aquí iría la lógica para enviar el mensaje (e.g., a un servicio de soporte o a Firestore)
                      await Future.delayed(const Duration(seconds: 2)); // Simula envío
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Mensaje enviado con éxito! Te contactaremos pronto."), backgroundColor: Colors.green));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAF0303), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: isSending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text("ENVIAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
