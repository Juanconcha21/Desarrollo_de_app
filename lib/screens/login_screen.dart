import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:market1/screens/home_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool isLogin = true;
  bool isLoading = false;
  bool isPasswordVisible = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController(); 
  final nameController = TextEditingController();
  final careerController = TextEditingController();
  final dobController = TextEditingController();
  String selectedRole = 'usuario'; // Rol por defecto

  @override
  void initState() {
    super.initState();
    auth.signOut();
  }

  // =================================================================
  // 1. INICIO DE SESIÓN CON GOOGLE 
  // =================================================================
  Future<void> _handleGoogleSignIn() async {

    setState(() => isLoading = true);
    try {
      UserCredential? result = await auth.signInWithGoogle();
      if (result != null && result.user != null) {
        User user = result.user!;
        bool isNewUser = result.additionalUserInfo?.isNewUser ?? false;

        // 1. REVISAMOS QUE SEA GMAIL
        if (user.email == null || !user.email!.toLowerCase().endsWith('@gmail.com')) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [Icon(Icons.domain_disabled, color: Colors.white), SizedBox(width: 12), Text("Solo se permiten correos @gmail.com")],
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.all(20),
              )
            );
          }
          return; 
        }

        // REVISAR VERIFICACIÓN (Si es nuevo, forzamos la pantalla de verificación)
        if (isNewUser || !user.emailVerified) {
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen())
            );
          }
          return;
        }

        // 2. COMPLETAR PERFIL
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['dob'] == 'No especificada') {
            await _showGoogleProfileDialog(user);
          }
        }
        
        // 3. NAVEGAMOS AL HOME
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(e.toString()))],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        )
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =================================================================
  // 2. INICIO DE SESIÓN / REGISTRO MANUAL
  // =================================================================
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      if (isLogin) {
        User? user = await auth.login(emailController.text.trim(), passwordController.text.trim());
        if (user != null) {
          if (!user.emailVerified) {
            if (mounted) {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => const VerifyEmailScreen())
              );
            }
          } else {
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            }
          }
        }
      } else {
        await auth.register(
          emailController.text.trim(),
          passwordController.text.trim(),
          nameController.text.trim(),
          careerController.text.trim(),
          dobController.text.trim(),
          selectedRole,
        );
        if (mounted) {
          String successMsg = "¡Registro exitoso! Revisa tu correo para verificar tu cuenta.";
          if (selectedRole == 'moderador') {
            successMsg += " Además, un administrador debe aprobar tu acceso antes de que puedas entrar.";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mark_email_read, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(successMsg)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.all(20),
              duration: const Duration(seconds: 7),
            )
          );
          setState(() => isLogin = true); 
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [const Icon(Icons.warning_amber_rounded, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(e.toString()))],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        )
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =================================================================
  // 3. INTERFAZ GRÁFICA (UI)
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50), 
               image: DecorationImage(
                 image: AssetImage('assets/proyectoua.jpg'), 
                 fit: BoxFit.cover,
               ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.6)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school, size: 80, color: Color(0xFFAF0303)),
                    const SizedBox(height: 10),
                    const Text("MARKETPLACE UA", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 40),

                    if (!isLogin) ...[
                      _buildTextField(nameController, "Nombre Completo", Icons.person),
                      _buildTextField(careerController, "Carrera", Icons.school_outlined),
                      _buildDateField(dobController, "Fecha de Nacimiento", Icons.cake, context), 
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.badge, color: Color(0xFFAF0303))),
                          items: const [
                            DropdownMenuItem(value: 'usuario', child: Text("Quiero comprar/vender")),
                            DropdownMenuItem(value: 'moderador', child: Text("Quiero ser Moderador")),
                          ],
                          onChanged: (val) => setState(() => selectedRole = val!),
                        ),
                      ),
                    ],
                    
                    _buildTextField(
                      emailController, 
                      "Ingrese su correo (@gmail.com)", 
                      Icons.email,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "El correo es obligatorio";
                        }
                        if (!val.trim().toLowerCase().endsWith('@gmail.com')) {
                          return "Solo se permiten correos @gmail.com";
                        }
                        return null;
                      }
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
                      child: TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: "Contraseña",
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFAF0303)),
                          suffixIcon: IconButton(
                            icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Falta la contraseña";
                          if (!isLogin) {
                            String pattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$';
                            RegExp regex = RegExp(pattern);
                            if (!regex.hasMatch(val)) {
                              return "Debe tener 8+ caracteres, mayúscula, minúscula, número y símbolo";
                            }
                          }
                          return null;
                        },
                      ),
                    ),

                    if (!isLogin)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
                        child: TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !isPasswordVisible,
                          decoration: const InputDecoration(
                            hintText: "Confirmar Contraseña",
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFAF0303)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          validator: (val) {
                            if (val!.isEmpty) return "Debes confirmar la contraseña";
                            if (val != passwordController.text) return "Las contraseñas no coinciden";
                            return null;
                          },
                        ),
                      ),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword, 
                          child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAF0303),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : Text(isLogin ? "INICIAR SESIÓN" : "REGISTRARSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/google_logo.png', height: 24),
                            const SizedBox(width: 12),
                            const Text("Continuar con Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(isLogin ? "¿No tienes cuenta? " : "¿Ya tienes cuenta? ", style: const TextStyle(color: Colors.white70)),
                        GestureDetector(
                          onTap: () => setState(() => isLogin = !isLogin),
                          child: Text(isLogin ? "Regístrate aquí" : "Ingresa aquí", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // 4. WIDGETS AUXILIARES
  // =================================================================
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {String? Function(String?)? validator}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: validator ?? (val) => val == null || val.isEmpty ? "Este campo es obligatorio" : null,
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String hint, IconData icon, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
      child: TextFormField(
        controller: controller,
        readOnly: true, 
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime(2000), 
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: Color(0xFFAF0303), onPrimary: Colors.white, onSurface: Colors.black),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() {
              controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
            });
          }
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: (val) => val!.isEmpty ? "Falta la fecha de nacimiento" : null,
      ),
    );
  }

  Future<void> _showGoogleProfileDialog(User user) async {
    final googleNameController = TextEditingController(text: user.displayName ?? '');
    final googleCareerController = TextEditingController();
    final googleDobController = TextEditingController();
    final formKeyGoogle = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Completa tu perfil UA", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
        content: Form(
          key: formKeyGoogle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Como ingresaste con Google, necesitamos un par de datos para tu perfil.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 15),
              _buildDialogField(googleNameController, "Nombre Completo", Icons.person),
              _buildDialogField(googleCareerController, "Carrera", Icons.school_outlined),
              _buildDateField(googleDobController, "Fecha Nacimiento", Icons.cake, context), 
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (formKeyGoogle.currentState!.validate()) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'fullName': googleNameController.text.trim(),
                  'career': googleCareerController.text.trim(),
                  'dob': googleDobController.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAF0303),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
            ),
            child: const Text("GUARDAR Y ENTRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final resetEmailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Recuperar Contraseña", style: TextStyle(color: Color(0xFFAF0303), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingresa tu correo @gmail.com y te enviaremos un enlace para restablecer tu clave."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                hintText: "usuario@gmail.com",
                prefixIcon: const Icon(Icons.email, color: Color(0xFFAF0303)),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.trim().isEmpty) return;
              try {
                await auth.sendPasswordResetEmail(resetEmailController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Enlace enviado. Revisa tu bandeja de entrada."),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAF0303),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("ENVIAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFFAF0303)),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        validator: (val) => val!.isEmpty ? "Dato obligatorio" : null,
      ),
    );
  }

}