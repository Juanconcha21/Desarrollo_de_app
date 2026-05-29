import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_profile_screen.dart';
import 'publish_screen.dart';
import 'product_detail_cloud.dart';
import 'my_products_screen.dart';
import 'inbox_screen.dart';
import 'pending_products_screen.dart';
import 'reports_screen.dart';
import 'admin_dashboard_screen.dart';
import 'user_management_screen.dart';
import 'app_config_screen.dart';
import 'action_logs_screen.dart';
import 'announcement_manager_screen.dart';
import 'package:market1/screens/login_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Esta es la pantalla principal de la aplicación.
/// Aquí gestiono el estado global de la sesión, la navegación mediante un IndexedStack para optimizar
/// el renderizado y la hidratación de datos del perfil del usuario.
class _HomeScreenState extends State<HomeScreen> {
  final auth = AuthService();
  final user = FirebaseAuth.instance.currentUser;
  
  // Índice para controlar el BottomNavigationBar. Empiezo en 1 (Para ti) como vista central.
  int _selectedIndex = 1; 
  bool isDarkMode = false;
  String userName = "Cargando...";
  String userCareer = "Cargando...";
  String userDob = "Cargando...";
  String userRole = "Cargando..."; 
  String accountStatus = "Cargando...";
  String? profileImageUrl;
  String? selectedFilterCategory; // Estado para el filtrado reactivo de productos

  @override
  void initState() {
    super.initState();
    _loadUserData();
    auth.saveDeviceToken(); // Asegura que las notificaciones lleguen a este dispositivo
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

  /// Hidratación del estado local desde Firestore.
  /// Recupero el documento del usuario para manejar el RBAC (Role Based Access Control).
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
            userRole = data['role'] ?? 'No especificado'; // Cargar rol
            accountStatus = data['accountStatus'] ?? 'No especificado'; // Cargar estado
            profileImageUrl = data['photoUrl'] != null && data['photoUrl'].isNotEmpty
                ? data['photoUrl']
                : null;

            // Auto-promoción: Si es el correo maestro, asegurar que sea admin en Firestore
            if (user?.email == 'marketuafire@gmail.com' && userRole != 'admin') {
              FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'role': 'admin'});
              userRole = 'admin';
            }
          });
        }
      } catch (e) {
        print("Error cargando perfil: $e");
      }
    }
  }

  /// Módulo de Moderación: Implemento este diálogo para que los usuarios envíen 
  /// reportes a la colección 'reports' en Firestore, permitiendo auditoría posterior.
  void _showReportDialog(String productId, Map<String, dynamic> productData) {
    final TextEditingController reportController = TextEditingController();
    String selectedReason = 'Contenido inapropiado';
    final List<String> reasons = [
      'Contenido inapropiado',
      'Fraude o Estafa',
      'Producto prohibido',
      'Spam',
      'Otros'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Color(0xFFAF0303)),
              SizedBox(width: 10),
              Text("Reportar Producto", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("¿Por qué deseas reportar esta publicación?", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setStateDialog(() => selectedReason = val!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Detalles adicionales (opcional)",
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
                await FirebaseFirestore.instance.collection('reports').add({
                  'productId': productId,
                  'productTitle': productData['title'],
                  'sellerId': productData['sellerId'],
                  'reporterId': user!.uid,
                  'reporterEmail': user!.email,
                  'reason': selectedReason,
                  'details': reportController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Reporte enviado. Gracias por ayudar a la comunidad."),
                      backgroundColor: Colors.orange[800],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.all(20),
                    ),
                  );
                }
              },
              child: const Text("ENVIAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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

    final currentUser = FirebaseAuth.instance.currentUser;
    // Defino las vistas principales del sistema.
    final List<Widget> screens = [
      _buildCategoriesTab(surfaceColor, textColor),
      _buildForYouTab(surfaceColor, textColor, mutedTextColor),
      _buildProfileTab(surfaceColor, textColor, mutedTextColor),
    ];

    // El Scaffold principal implementa el patrón de navegación Bottom Navigation.
    // Uso IndexedStack para que al cambiar de pestaña no se pierda el estado ni el scroll de los módulos.
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

  /// Mapeo automático de estilos. 
  /// Si el Admin añade "Tecnología de punta", el sistema detecta "tecno" y pone el icono de PC.
  Map<String, dynamic> _getCategoryStyle(String title) {
    final name = title.toLowerCase();
    if (name.contains('electro')) return {'icon': Icons.kitchen, 'color': Colors.blueGrey};
    if (name.contains('tecno') || name.contains('comput')) return {'icon': Icons.computer, 'color': Colors.blue};
    if (name.contains('mueble')) return {'icon': Icons.chair, 'color': Colors.brown};
    if (name.contains('hogar') || name.contains('casa')) return {'icon': Icons.home, 'color': Colors.green};
    if (name.contains('ropa') || name.contains('moda')) return {'icon': Icons.checkroom, 'color': Colors.red};
    if (name.contains('libro') || name.contains('estudio')) return {'icon': Icons.menu_book_rounded, 'color': Colors.orange};
    if (name.contains('deporte')) return {'icon': Icons.sports_soccer_rounded, 'color': Colors.indigo};
    
    return {'icon': Icons.category_rounded, 'color': Colors.teal}; // Icono por defecto
  }

  /// Módulo de Categorías: Estructura de navegación basada en cuadrícula (GridView).
  Widget _buildCategoriesTab(Color surfaceColor, Color textColor) {
    final categoriesStream = FirebaseFirestore.instance.collection('categories').snapshots();

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
            child: StreamBuilder<QuerySnapshot>(
              stream: categoriesStream,
              builder: (context, snapshot) {
                // Iniciamos con las categorías por defecto
                final List<String> categoryTitles = ['Electrodomésticos', 'Tecnología', 'Muebles', 'Hogar', 'Ropa y Accesorios', 'Otros'];
                
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final String name = doc['name'] as String;
                    // Solo añadimos si no existe ya en la lista para evitar duplicados
                    if (!categoryTitles.contains(name)) categoryTitles.add(name);
                  }
                }

                // Aseguramos que 'Otros' siempre quede al final de la lista
                if (categoryTitles.contains('Otros')) {
                  categoryTitles.remove('Otros');
                  categoryTitles.add('Otros');
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: categoryTitles.length,
                  itemBuilder: (context, index) {
                    final title = categoryTitles[index];
                    final style = _getCategoryStyle(title);

                    return GestureDetector(
                      onTap: () => setState(() { selectedFilterCategory = title; _selectedIndex = 1; }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: (style['color'] as Color).withOpacity(isDarkMode ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(style['icon'] as IconData, color: style['color'] as Color, size: 30),
                            ),
                            const SizedBox(height: 10),
                            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  /// Feed Principal (Para Ti): 
  /// Implemento una arquitectura orientada a eventos mediante StreamBuilder que escucha 
  /// en tiempo real la colección 'products' de Firestore.
  Widget _buildForYouTab(
    Color surfaceColor,
    Color textColor,
    Color mutedTextColor,
  ) {
    if (userRole == "Cargando...") {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFAF0303)));
    }

    Query productsQuery = FirebaseFirestore.instance.collection('products');

    // Ocultar productos marcados como vendidos en el Home
    productsQuery = productsQuery.where('isSold', isEqualTo: false);

    // Lógica de Filtrado y RBAC:
    // Los usuarios normales solo ven 'approved', los moderadores/admin ven todo el flujo.
    bool isStaff = userRole == 'admin' || userRole == 'moderador';
    if (!isStaff) {
      productsQuery = productsQuery.where('status', isEqualTo: 'approved');
    }

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

        // Banner de Anuncios: Implementado como un Single Source of Truth desde Firestore.
        // Esto me permite cambiar avisos a toda la universidad sin actualizar la App.
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('announcement').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
            var data = snapshot.data!.data() as Map<String, dynamic>;
            if (!(data['isActive'] ?? false)) return const SizedBox.shrink();
            
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFAF0303), Color(0xFF8B0000)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(data['message'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        ),

        Expanded(
          // Renderizado asíncrono de la lista de productos.
          child: StreamBuilder<QuerySnapshot>(
            stream: productsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Error: ${snapshot.error}\n\nSi ves un link en la consola de VS Code, haz clic para crear el índice de Firestore.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                );
              }

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
                      // Implemento el detalle del producto en un ModalBottomSheet con efecto Blur (Frosted Glass).
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
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, -5),
                                    )
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
                                                productId: products[index].id,
                                                isDarkMode: isDarkMode,
                                                userRole: userRole,
                                              ),
                                              const SizedBox(height: 40), 
                                              if (productData['location'] != null) ...[
                                                const Text("Ubicación del vendedor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const SizedBox(height: 10),
                                                Container(
                                                  height: 200,
                                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade300)),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(24),
                                                    child: GoogleMap(
                                                      initialCameraPosition: CameraPosition(
                                                        target: LatLng(
                                                          (productData['location'] as GeoPoint).latitude,
                                                          (productData['location'] as GeoPoint).longitude,
                                                        ),
                                                        zoom: 15,
                                                      ),
                                                      markers: {
                                                        Marker(
                                                          markerId: const MarkerId("seller"),
                                                          position: LatLng((productData['location'] as GeoPoint).latitude, (productData['location'] as GeoPoint).longitude),
                                                          infoWindow: InfoWindow(title: "Vendedor: ${productData['sellerName']}"),
                                                        ),
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 40),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 25,
                                    right: 25,
                                    child: Container(
                                      color: Colors.transparent,
                                      child: IconButton(
                                        icon: const Icon(Icons.flag_rounded, color: Color(0xFFAF0303), size: 24),
                                        style: IconButton.styleFrom(
                                          backgroundColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                                        ),
                                        tooltip: "Reportar",
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showReportDialog(products[index].id, productData);
                                        },
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
    // Componente atómico para el producto.
    // Manejo la lógica visual de 'isSold' mediante decoraciones de texto y filtros de color.
    bool isSold = product['isSold'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title'] ?? 'Sin título',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSold ? mutedTextColor : textColor,
                    fontSize: 15,
                    letterSpacing: -0.5,
                    decoration: isSold ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\$${product['price'] ?? '0'}',
                      style: TextStyle(
                        color: isSold ? Colors.grey : const Color(0xFFAF0303),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const Spacer(),
                    if (!isSold)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAF0303).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("Nuevo", style: TextStyle(color: Color(0xFFAF0303), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
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
    /// Módulo de Perfil y Configuración:
    /// Aquí centralizo la lógica de gestión de cuenta y los accesos condicionales 
    /// para la administración del sistema.
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
              _infoChip(Icons.badge, userRole, textColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

                  if (userRole == 'moderador' || userRole == 'admin') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 15, top: 20, bottom: 10),
                      child: Text("Gestión de Moderación", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    ),
                    _profileOptionTile(
                      icon: Icons.fact_check_outlined,
                      title: 'Productos Pendientes',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PendingProductsScreen(),
                          ),
                        );
                      },
                    ),
                    _profileOptionTile(
                      icon: Icons.report_problem_outlined,
                      title: 'Revisar Reportes',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  if (userRole == 'admin' && user?.email == 'marketuafire@gmail.com') ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 15, top: 20, bottom: 10),
                      child: Text("Panel de Administrador", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[900])),
                    ),
                    _profileOptionTile(
                      icon: Icons.admin_panel_settings,
                      title: 'Dashboard Global',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                      },
                    ),
                    _profileOptionTile(
                      icon: Icons.people_alt_outlined,
                      title: 'Gestión de Usuarios (CRUD)',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                      },
                    ),
                    _profileOptionTile(
                      icon: Icons.settings_applications_rounded,
                      title: 'Gestor de Aplicación (Sedes/Categorías)',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AppConfigScreen()));
                      },
                    ),
                    _profileOptionTile(
                      icon: Icons.history_edu_rounded,
                      title: 'Logs de Acciones',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ActionLogsScreen()));
                      },
                    ),
                    _profileOptionTile(
                      icon: Icons.notification_add_rounded,
                      title: 'Sistema de Anuncios',
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementManagerScreen()));
                      },
                    ),
                  ],

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
                                onPressed: () => Navigator.of(context).pop(),
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
                                      (route) => false,
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

  /// Gestión de Seguridad: 
  /// Implemento el cambio de credenciales requiriendo re-autenticación (pattern de Firebase) 
  /// para asegurar que el usuario que intenta el cambio es el dueño de la sesión actual.
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