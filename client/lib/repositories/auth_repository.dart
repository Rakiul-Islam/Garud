import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user is already logged in
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  Future<void> login(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);

    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'token': token}, SetOptions(merge: true));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}