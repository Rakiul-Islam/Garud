import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user is already logged in
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  Future<void> login(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);

    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'token': token}, SetOptions(merge: true));
    }
  }

  Future<void> signup(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'token': token,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'guardians': [],   // Initialize empty guardians array
        'proteges': [],    // Initialize empty proteges array
      });
    }
  }
    Future<void> signupWithGarudId(String email, String password, String garudId, String name, String phoneNumber, bool enableAlerts) async {
    // Run validation checks again to ensure Garud ID is valid and not already assigned
    final validIdDoc = await _firestore
        .collection('garudIdMap')
        .doc('0')
        .get();
    
    if (!validIdDoc.exists) {
      throw Exception('Unable to verify Garud ID. Please try again later.');
    }
    
    final validIds = List<String>.from(validIdDoc.data()?['ValidGarudIDList'] ?? []);
    
    if (!validIds.contains(garudId)) {
      throw Exception('Invalid Garud ID. Please enter a valid ID.');
    }
    
    final assignedIdDoc = await _firestore
        .collection('garudIdMap')
        .doc(garudId)
        .get();
    
    if (assignedIdDoc.exists) {
      throw Exception('This Garud ID is already assigned to another user.');
    }
    
    // Create the user account
    final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    // Get FCM token for notifications
    String? token = await FirebaseMessaging.instance.getToken();
    
    // Use a batch write to ensure consistency
    final batch = _firestore.batch();
    
    // Create the user document
    final userRef = _firestore.collection('users').doc(userCredential.user!.uid);    batch.set(userRef, {
      'token': token,
      'email': email,
      'garudId': garudId,
      'name': name,
      'phoneNumber': phoneNumber,
      'enableAlerts': enableAlerts,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'status': 'active',
      'guardians': [],   // Initialize empty guardians array
      'proteges': [],    // Initialize empty proteges array
    });
    
    // Create the garudId mapping document
    final garudIdRef = _firestore.collection('garudIdMap').doc(garudId);
    batch.set(garudIdRef, {
      'uid': userCredential.user!.uid,
      'email': email,
      'assignedAt': FieldValue.serverTimestamp(),
    });
    
    // Commit the batch
    await batch.commit();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}