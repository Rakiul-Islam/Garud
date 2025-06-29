import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garudclient/data/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel> login(
      {required String email, required String password}) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed, user not found.');
      }

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw Exception('User data not found.');
      }

      // Update last login time
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Re-fetch the document to get the updated lastLogin time
      final updatedUserDoc =
          await _firestore.collection('users').doc(user.uid).get();

      return UserModel.fromDocument(updatedUserDoc);
    } on FirebaseAuthException catch (e) {
      // Convert Firebase specific errors to a more generic message
      throw Exception(e.message ?? 'An unknown authentication error occurred.');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  Future<UserModel> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      throw Exception('User document not found in Firestore.');
    }

    return UserModel.fromDocument(userDoc);
  }

  Future<void> signup(String email, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An unknown authentication error occurred.');
    }
  }

  Future<void> signupWithGarudId(String email, String password, String garudId,
      String name, String phoneNumber, bool enableAlerts) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Signup failed, user not created.');
      }

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        garudId: garudId,
        enableAlerts: enableAlerts,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        status: 'active',
        guardians: [],
        proteges: [],
      );

      final batch = _firestore.batch();

      final userRef =
          _firestore.collection('users').doc(userCredential.user!.uid);
      batch.set(userRef, userModel.toMap());

      // Create the garudId mapping document
      final garudIdRef = _firestore.collection('garudIdMap').doc(garudId);
      batch.set(garudIdRef, {
        'uid': userCredential.user!.uid,
        'email': email,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An unknown authentication error occurred.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Logout failed.');
    }
  }

  // You can add other methods like signUp, signOut, etc. here
}
