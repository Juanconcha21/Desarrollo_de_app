import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

/// Capa de Abstracción de Datos (DAL) para Autenticación y Gestión de Usuarios.
/// Aquí encapsulo toda la lógica de negocio de Firebase Auth y el perfil extendido en Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Notificaciones Push:
  /// Registro el token FCM del dispositivo actual en el perfil del usuario para 
  /// permitir que el backend (Cloud Functions) envíe alertas personalizadas.
  Future<void> saveDeviceToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    User? user = _auth.currentUser;
    if (token != null && user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Traductor de Excepciones: 
  /// Implemento este mapper para convertir códigos de error técnicos de Firebase en mensajes legibles para el usuario final.
  String getSpanishErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password': return 'La contraseña es demasiado débil.';
      case 'email-already-in-use': return 'Este correo ya está registrado.';
      case 'user-not-found': return 'No existe un usuario con este correo.';
      case 'wrong-password': return 'Contraseña incorrecta.';
      case 'invalid-email': return 'El formato del correo es inválido.';
      case 'invalid-credential': return 'Credenciales incorrectas.';
      default: return 'Ocurrió un error: ${e.message}';
    }
  }

  /// Pipeline de Registro:
  /// Crea el usuario en Firebase Auth y simultáneamente inicializa su documento de perfil en Firestore 
  /// con roles predeterminados y estados de cuenta.
  Future<User?> register(String email, String password, String name, String career, String dob, String selectedRole) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        String finalRole = selectedRole;
        if (email.trim().toLowerCase() == "marketuafire@gmail.com") { 
          finalRole = "admin";
        }

        bool isApproved = (finalRole != "moderador");

        await _firestore.collection('users').doc(user.uid).set({
          'fullName': name, 
          'career': career, 
          'dob': dob, 
          'email': email, 
          'createdAt': FieldValue.serverTimestamp(),
          'role': finalRole,
          'accountStatus': 'active',
          'strikes': 0,
          'isApproved': isApproved,
        });

        await user.sendEmailVerification(); // Validación al correo obligatoria
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw getSpanishErrorMessage(e); // Usamos el traductor
    } catch (e) {
      throw e.toString();
    }
  }

  /// Pipeline de Inicio de Sesión:
  /// Incluye verificaciones de seguridad adicionales (estado de baneo y aprobación de moderador).
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {

        // 2. Verificación de Aprobación de Moderador
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(result.user!.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          if (userData['role'] == 'moderador' && userData['isApproved'] == false) {
            await _auth.signOut();
            throw "Tu cuenta de moderador está pendiente de aprobación por el administrador.";
          }
          if (userData['accountStatus'] == 'banned') {
            await _auth.signOut();
            throw "Tu cuenta ha sido suspendida permanentemente por infringir las normas de la comunidad.";
          }
        }
      }
      await saveDeviceToken();
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw getSpanishErrorMessage(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// Estrategia de Autenticación Social (OAuth 2.0): 
  /// Implemento el flujo de Google Sign-In manejando la creación automática de perfil si el usuario es nuevo.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          if (userData['accountStatus'] == 'banned') {
            await signOut();
            throw "Esta cuenta de Google está asociada a un usuario baneado.";
          }
        }

        if (!doc.exists) {
          await user.sendEmailVerification();
          
          String finalRole = "usuario";
          if (user.email?.trim().toLowerCase() == "marketuafire@gmail.com") {
            finalRole = "admin";
          }

          await _firestore.collection('users').doc(user.uid).set({
            'fullName': user.displayName ?? '', 'career': 'No especificada', 'dob': 'No especificada',
            'email': user.email, 'photoUrl': user.photoURL, 'createdAt': FieldValue.serverTimestamp(),
            'role': finalRole, 'accountStatus': 'active', 'strikes': 0, 'isApproved': true,
          });
        }
        await saveDeviceToken();
      }
      return result;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateProfile({
    required String name,
    required String career,
    required String dob,
    String? photoUrl,
  }) async {
    String uid = _auth.currentUser!.uid;
    Map<String, dynamic> data = {
      'fullName': name,
      'career': career,
      'dob': dob,
    };
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> updateUserByAdmin(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').orderBy('createdAt', descending: true).snapshots();
  }

  /// Gestión de Moderación - Sistema de Strikes:
  /// Utilizo una Transacción de Firestore (Atomic Update) para garantizar que el contador 
  /// de strikes y el cambio de estado a 'banned' ocurran de forma consistente, evitando 
  /// condiciones de carrera (Race Conditions).
  Future<void> applyStrike(String userId) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        int currentStrikes = (userDoc.data() as Map<String, dynamic>)['strikes'] ?? 0;
        int newStrikes = currentStrikes + 1;
        
        String newStatus = newStrikes >= 3 ? 'banned' : 'active';

        transaction.update(userRef, {
          'strikes': newStrikes,
          'accountStatus': newStatus,
          'lastStrikeAt': FieldValue.serverTimestamp(),
          'needsStrikeNotification': true, 
        });
      });
    } catch (e) {
      throw "Error al aplicar strike: $e";
    }
  }

  Future<String?> uploadProfilePicture(String path) async {
    try {
      File file = File(path);
      String uid = _auth.currentUser!.uid;
      Reference ref = FirebaseStorage.instance.ref().child('profiles').child('$uid.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw getSpanishErrorMessage(e);
    } catch (e) {
      throw "No se pudo enviar el correo de recuperación. Inténtalo más tarde.";
    }
  }
}