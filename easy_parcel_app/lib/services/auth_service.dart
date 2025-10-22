import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  Future<User?> signUp(
    String email,
    String password,
    String name,
    String role,
    String phoneNumber,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        User newUser = User(
          email: email,
          name: name,
          role: role,
          phoneNumber: phoneNumber,
        );

        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'name': name,
          'role': role,
          'phoneNumber': phoneNumber,
        });

        return newUser;
      }
      return null;
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get currentUser {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          return User(
            email: data['email'] ?? '',
            name: data['name'] ?? '',
            role: data['role'] ?? '',
            phoneNumber: data['phoneNumber'] ?? '',
          );
        }
      }
      return null;
    });
  }
}
