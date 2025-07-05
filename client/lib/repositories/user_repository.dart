import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/data/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<DocumentSnapshot> findUserByEmail(String email) {
    return _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isEmpty) {
        throw Exception("User not found");
      }
      return snapshot.docs.first;
    });
  }

  Future<DocumentSnapshot> getUserData(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

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

  Future<void> addGuardian(String currentUserUid, String guardianUid) async {
    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUserUid);
    final guardianRef = _firestore.collection('users').doc(guardianUid);

    batch.update(currentUserRef, {
      'guardians': FieldValue.arrayUnion([
        {'uid': guardianUid, 'status': 'requested'}
      ])
    });

    batch.update(guardianRef, {
      'proteges': FieldValue.arrayUnion([
        {'uid': currentUserUid, 'status': 'requested'}
      ])
    });

    await batch.commit();
  }

  Future<void> acceptGuardian(String currentUserUid, String protegeUid) async {
    final batch = _firestore.batch();
    final protegeRef = _firestore.collection('users').doc(protegeUid);
    final currentUserRef = _firestore.collection('users').doc(currentUserUid);

    final protegeDoc = await protegeRef.get();
    final protegeGuardians =
        List<Map<String, dynamic>>.from(protegeDoc.data()?['guardians'] ?? []);
    final updatedProtegeGuardians = protegeGuardians.map((guardian) {
      if (guardian['uid'] == currentUserUid) {
        return {'uid': currentUserUid, 'status': 'accepted'};
      }
      return guardian;
    }).toList();

    batch.update(protegeRef, {'guardians': updatedProtegeGuardians});

    final currentUserDoc = await currentUserRef.get();
    final currentProteges =
        List<Map<String, dynamic>>.from(currentUserDoc.data()?['proteges'] ?? []);
    final updatedCurrentProteges = currentProteges.map((protege) {
      if (protege['uid'] == protegeUid) {
        return {'uid': protegeUid, 'status': 'accepted'};
      }
      return protege;
    }).toList();

    batch.update(currentUserRef, {'proteges': updatedCurrentProteges});

    await batch.commit();
  }

  Future<void> rejectGuardian(String currentUserUid, String protegeUid) async {
    final batch = _firestore.batch();
    final protegeRef = _firestore.collection('users').doc(protegeUid);
    final currentUserRef = _firestore.collection('users').doc(currentUserUid);

    batch.update(protegeRef, {
      'guardians': FieldValue.arrayRemove([
        {'uid': currentUserUid, 'status': 'requested'}
      ])
    });

    batch.update(currentUserRef, {
      'proteges': FieldValue.arrayRemove([
        {'uid': protegeUid, 'status': 'requested'}
      ])
    });

    await batch.commit();
  }

  Future<List<PublicUserModel>> getGuardians(String uid) async {
    final userDoc = await getUserData(uid);
    final userData = userDoc.data() as Map<String, dynamic>?;
    final guardianData =
        List<Map<String, dynamic>>.from(userData?['guardians'] ?? []);
    List<PublicUserModel> tempList = [];

    for (Map<String, dynamic> guardianInfo in guardianData) {
      final guardianUid = guardianInfo['uid'];
      final status = guardianInfo['status'];
      final guardianDoc = await getUserData(guardianUid);
      final guardianDataMap = guardianDoc.data() as Map<String, dynamic>?;

      if (guardianDoc.exists && guardianDataMap?['email'] != null) {
        final data = guardianDataMap!;
        tempList.add(PublicUserModel(
          uid: guardianUid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phoneNumber: data['phoneNumber'] ?? '',
          garudId: data['garudId'] ?? '',
          status: status,
        ));
      }
    }
    return tempList;
  }

  Future<void> deleteGuardian(String currentUserUid, String guardianUid) async {
    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUserUid);
    final guardianRef = _firestore.collection('users').doc(guardianUid);

    final currentUserDoc = await currentUserRef.get();
    final guardianDoc = await guardianRef.get();

    final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
    final guardianDataMap = guardianDoc.data() as Map<String, dynamic>?;

    final currentGuardians =
        List<Map<String, dynamic>>.from(currentUserData?['guardians'] ?? []);
    final guardianToRemove = currentGuardians.firstWhere(
        (guardian) => guardian['uid'] == guardianUid,
        orElse: () => {});

    if (guardianToRemove.isEmpty) {
      throw Exception("Guardian not found");
    }

    final guardianProteges =
        List<Map<String, dynamic>>.from(guardianDataMap?['proteges'] ?? []);
    final protegeToRemove = guardianProteges.firstWhere(
        (protege) => protege['uid'] == currentUserUid,
        orElse: () => {});

    batch.update(currentUserRef, {
      'guardians': FieldValue.arrayRemove([guardianToRemove])
    });

    if (protegeToRemove.isNotEmpty) {
      batch.update(guardianRef, {
        'proteges': FieldValue.arrayRemove([protegeToRemove])
      });
    }

    await batch.commit();
  }

  Future<List<PublicUserModel>> getProteges(String uid) async {
    final userDoc = await getUserData(uid);
    final userData = userDoc.data() as Map<String, dynamic>?;
    final protegeData =
        List<Map<String, dynamic>>.from(userData?['proteges'] ?? []);
    List<PublicUserModel> tempList = [];

    for (Map<String, dynamic> protegeInfo in protegeData) {
      final protegeUid = protegeInfo['uid'];
      final status = protegeInfo['status'];
      final protegeDoc = await getUserData(protegeUid);
      final protegeDataMap = protegeDoc.data() as Map<String, dynamic>?;

      if (protegeDoc.exists && protegeDataMap?['email'] != null) {
        final data = protegeDataMap!;
        tempList.add(PublicUserModel(
          uid: protegeUid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phoneNumber: data['phoneNumber'] ?? '',
          garudId: data['garudId'] ?? '',
          status: status,
        ));
      }
    }
    return tempList;
  }

  Future<void> deleteProtege(String currentUserUid, String protegeUid) async {
    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUserUid);
    final protegeRef = _firestore.collection('users').doc(protegeUid);

    final currentUserDoc = await currentUserRef.get();
    final protegeDoc = await protegeRef.get();

    final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
    final protegeDataMap = protegeDoc.data() as Map<String, dynamic>?;

    final currentProteges =
        List<Map<String, dynamic>>.from(currentUserData?['proteges'] ?? []);
    final protegeToRemove = currentProteges.firstWhere(
        (protege) => protege['uid'] == protegeUid,
        orElse: () => {});

    if (protegeToRemove.isEmpty) {
      throw Exception("Protege not found");
    }

    final protegeGuardians =
        List<Map<String, dynamic>>.from(protegeDataMap?['guardians'] ?? []);
    final guardianToRemove = protegeGuardians.firstWhere(
        (guardian) => guardian['uid'] == currentUserUid,
        orElse: () => {});

    batch.update(currentUserRef, {
      'proteges': FieldValue.arrayRemove([protegeToRemove])
    });

    if (guardianToRemove.isNotEmpty) {
      batch.update(protegeRef, {
        'guardians': FieldValue.arrayRemove([guardianToRemove])
      });
    }

    await batch.commit();
  }

  Future<void> updateFCMToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'token': token,
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel> updateUser(String uid, String? fcmToken) async {
    final userDoc = await getUserData(uid);
    if (!userDoc.exists) {
      throw Exception("User data not found");
    }
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await updateFCMToken(uid, fcmToken);
    }
    return UserModel.fromDocument(userDoc);
  }

  Future<DocumentSnapshot> getUserProfile(String uid) {
    return getUserData(uid);
  }
}
