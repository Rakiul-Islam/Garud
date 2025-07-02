import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garudclient/data/models/public_user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PublicUserModel> getPublicUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return PublicUserModel.fromMap(doc.data()!);
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      rethrow;
    }
  }
}
