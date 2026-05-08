import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  // 1. REGISTRO
  Future<User?> register(String email, String password, String name, String career, String dob) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fullName': name, 'career': career, 'dob': dob, 'email': email, 'createdAt': FieldValue.serverTimestamp(),
        });
        await user.sendEmailVerification(); // Validación al correo obligatoria
        await _auth.signOut();
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw getSpanishErrorMessage(e); // Usamos el traductor
    } catch (e) {
      throw e.toString();
    }
  }

  // 2. LOGIN 
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null && !result.user!.emailVerified) {
        await _auth.signOut();
        throw "Debes verificar tu correo institucional. Revisa tu bandeja de entrada o SPAM.";
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw getSpanishErrorMessage(e); // Usamos el traductor
    } catch (e) {
      throw e.toString();
    }
  }

  // 3. GOOGLE
  Future<User?> signInWithGoogle() async {
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
        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'fullName': user.displayName ?? '', 'career': 'No especificada', 'dob': 'No especificada', // Añadir photoUrl aquí
            'email': user.email, 'photoUrl': user.photoURL, 'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } catch (e) {
      throw "Error iniciando sesión con Google.";
    }
  }

  // 4. ACTUALIZAR DATOS
  Future<void> updateUserData(String name, String career, String dob) async {
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({
      'fullName': name,
      'career': career,
      'dob': dob,
    });
  }

  // 5. CERRAR SESIÓN
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