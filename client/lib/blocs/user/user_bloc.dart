// blocs/user/user_bloc.dart :
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:garudclient/services/fcm_service.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/data/models/user_model.dart';

import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final FCMService _fcmService = FCMService();

  UserBloc() : super(UserInitial()) {
    on<AddGuardianRequested>(_onAddGuardianRequested);
    on<FetchGuardiansRequested>(_onFetchGuardiansRequested);
    on<DeleteGuardianRequested>(_onDeleteGuardianRequested);
    on<FetchProtegesRequested>(_onFetchProtegesRequested);
    on<DeleteProtegeRequested>(_onDeleteProtegeRequested);
    on<AcceptGuardianRequested>(_onAcceptGuardianRequested);
    on<RejectGuardianRequested>(_onRejectGuardianRequested);
    on<UpdateFCMTokenRequested>(_onUpdateFCMTokenRequested);
    on<UpdateUserRequested>(_onUpdateUserRequested);
    on<LoadUserProfile>(_onLoadUserProfile);
  }

  Future<void> _onAddGuardianRequested(
      AddGuardianRequested event, Emitter<UserState> emit) async {
    emit(GuardianAddInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Find the guardian user by email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: event.guardianEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("Guardian not found");
      }

      final guardianUid = querySnapshot.docs.first.id;

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Add guardian request to current user's document
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      // Get current user data for notification
      final currentUserDoc = await currentUserRef.get();
      final currentUserEmail =
          currentUserDoc.data()?['email'] ?? currentUser.email ?? 'A user';

      // Check if guardian already exists or is already requested
      final currentGuardians = List<Map<String, dynamic>>.from(
          currentUserDoc.data()?['guardians'] ?? []);
      
      final existingGuardian = currentGuardians.firstWhere(
        (guardian) => guardian['uid'] == guardianUid,
        orElse: () => {},
      );

      if (existingGuardian.isNotEmpty) {
        throw Exception("Guardian already exists or request already sent");
      }

      // Add guardian with "requested" status to current user's document
      batch.update(currentUserRef, {
        'guardians': FieldValue.arrayUnion([
          {'uid': guardianUid, 'status': 'requested'}
        ])
      });

      // Add current user as protege request to guardian's document
      final guardianRef =
          FirebaseFirestore.instance.collection('users').doc(guardianUid);

      batch.update(guardianRef, {
        'proteges': FieldValue.arrayUnion([
          {'uid': currentUser.uid, 'status': 'requested'}
        ])
      });

      // Commit the batch write
      await batch.commit();

      // Send notification to the guardian
      final guardianData = querySnapshot.docs.first.data();
      final guardianToken = guardianData['token'];

      if (guardianToken != null) {
        await _fcmService.sendNotification(
          targetToken: guardianToken,
          title: 'Guardian Request',
          body: '$currentUserEmail wants to add you as their guardian',
        );
      }

      emit(GuardianAdded());
      add(FetchGuardiansRequested()); // refresh list
    } catch (e) {
      emit(GuardianAddFailed(e.toString()));
    }
  }

  Future<void> _onAcceptGuardianRequested(
      AcceptGuardianRequested event, Emitter<UserState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final batch = FirebaseFirestore.instance.batch();

      // Update protege's guardian status to "accepted"
      final protegeRef =
          FirebaseFirestore.instance.collection('users').doc(event.protegeUid);
      
      final protegeDoc = await protegeRef.get();
      final protegeGuardians = List<Map<String, dynamic>>.from(
          protegeDoc.data()?['guardians'] ?? []);

      // Remove the old request and add accepted status
      final updatedProtegeGuardians = protegeGuardians.map((guardian) {
        if (guardian['uid'] == currentUser.uid) {
          return {'uid': currentUser.uid, 'status': 'accepted'};
        }
        return guardian;
      }).toList();

      batch.update(protegeRef, {'guardians': updatedProtegeGuardians});

      // Update current user's protege status to "accepted"
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      
      final currentUserDoc = await currentUserRef.get();
      final currentProteges = List<Map<String, dynamic>>.from(
          currentUserDoc.data()?['proteges'] ?? []);

      final updatedCurrentProteges = currentProteges.map((protege) {
        if (protege['uid'] == event.protegeUid) {
          return {'uid': event.protegeUid, 'status': 'accepted'};
        }
        return protege;
      }).toList();

      batch.update(currentUserRef, {'proteges': updatedCurrentProteges});

      // Commit the batch write
      await batch.commit();

      // Send notification to protege
      final protegeToken = protegeDoc.data()?['token'];
      final currentUserEmail = currentUserDoc.data()?['email'] ?? 'Guardian';

      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Request Accepted',
          body: '$currentUserEmail has accepted your guardian request',
        );
      }

      add(FetchProtegesRequested()); // refresh list
    } catch (e) {
      emit(ProtegeAcceptFailed(e.toString()));
    }
  }

  Future<void> _onRejectGuardianRequested(
      RejectGuardianRequested event, Emitter<UserState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final batch = FirebaseFirestore.instance.batch();

      // Remove from protege's guardians list
      final protegeRef =
          FirebaseFirestore.instance.collection('users').doc(event.protegeUid);
      
      batch.update(protegeRef, {
        'guardians': FieldValue.arrayRemove([
          {'uid': currentUser.uid, 'status': 'requested'}
        ])
      });

      // Remove from current user's proteges list
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      batch.update(currentUserRef, {
        'proteges': FieldValue.arrayRemove([
          {'uid': event.protegeUid, 'status': 'requested'}
        ])
      });

      // Commit the batch write
      await batch.commit();

      // Send notification to protege
      final protegeDoc = await protegeRef.get();
      final protegeToken = protegeDoc.data()?['token'];
      final currentUserDoc = await currentUserRef.get();
      final currentUserEmail = currentUserDoc.data()?['email'] ?? 'Guardian';

      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Request Rejected',
          body: '$currentUserEmail has rejected your guardian request',
        );
      }

      add(FetchProtegesRequested()); // refresh list
    } catch (e) {
      emit(ProtegeRejectFailed(e.toString()));
    }
  }

  Future<void> _onFetchGuardiansRequested(
      FetchGuardiansRequested event, Emitter<UserState> emit) async {
    emit(GuardiansLoadInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final guardianData = List<Map<String, dynamic>>.from(
          userDoc.data()?['guardians'] ?? []);

      List<PublicUserModel> tempList = [];

      for (Map<String, dynamic> guardianInfo in guardianData) {
        final uid = guardianInfo['uid'];
        final status = guardianInfo['status'];
        
        final guardianDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
            
        if (guardianDoc.exists && guardianDoc.data()?['email'] != null) {
          final data = guardianDoc.data()!;
          tempList.add(PublicUserModel(
            uid: uid,
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            phoneNumber: data['phoneNumber'] ?? '',
            garudId: data['garudId'] ?? '',
            status: status,
          ));
        }
      }

      emit(GuardiansLoaded(tempList));
    } catch (e) {
      emit(GuardianLoadFailed(e.toString()));
    }
  }

  Future<void> _onDeleteGuardianRequested(
      DeleteGuardianRequested event, Emitter<UserState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Get current user data for notification
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final currentUserDoc = await currentUserRef.get();
      final currentUserEmail =
          currentUserDoc.data()?['email'] ?? currentUser.email ?? 'A protege';

      // Get guardian data for notification
      final guardianRef =
          FirebaseFirestore.instance.collection('users').doc(event.uidToRemove);
      final guardianDoc = await guardianRef.get();
      final guardianToken = guardianDoc.data()?['token'];

      // Find the guardian entry to remove
      final currentGuardians = List<Map<String, dynamic>>.from(
          currentUserDoc.data()?['guardians'] ?? []);
      
      final guardianToRemove = currentGuardians.firstWhere(
        (guardian) => guardian['uid'] == event.uidToRemove,
        orElse: () => {},
      );

      if (guardianToRemove.isEmpty) {
        throw Exception("Guardian not found");
      }

      // Find the protege entry to remove from guardian's document
      final guardianData = guardianDoc.data();
      final guardianProteges = List<Map<String, dynamic>>.from(
          guardianData?['proteges'] ?? []);
      
      final protegeToRemove = guardianProteges.firstWhere(
        (protege) => protege['uid'] == currentUser.uid,
        orElse: () => {},
      );

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Remove guardian from current user's document
      batch.update(currentUserRef, {
        'guardians': FieldValue.arrayRemove([guardianToRemove])
      });

      // Remove current user as protege from guardian's document
      if (protegeToRemove.isNotEmpty) {
        batch.update(guardianRef, {
          'proteges': FieldValue.arrayRemove([protegeToRemove])
        });
      }

      // Commit the batch write
      await batch.commit();

      // Send notification to guardian about removal
      if (guardianToken != null) {
        await _fcmService.sendNotification(
          targetToken: guardianToken,
          title: 'Guardian Relationship Ended',
          body: '$currentUserEmail has removed you as their guardian',
        );
      }

      add(FetchGuardiansRequested());
    } catch (e) {
      emit(GuardianDeleteFailed(e.toString()));
    }
  }

  Future<void> _onFetchProtegesRequested(
      FetchProtegesRequested event, Emitter<UserState> emit) async {
    emit(ProtegesLoadInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final protegeData = List<Map<String, dynamic>>.from(
          userDoc.data()?['proteges'] ?? []);

      List<PublicUserModel> tempList = [];

      for (Map<String, dynamic> protegeInfo in protegeData) {
        final uid = protegeInfo['uid'];
        final status = protegeInfo['status'];
        
        final protegeDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
            
        if (protegeDoc.exists && protegeDoc.data()?['email'] != null) {
          final data = protegeDoc.data()!;
          tempList.add(PublicUserModel(
            uid: uid,
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            phoneNumber: data['phoneNumber'] ?? '',
            garudId: data['garudId'] ?? '',
            status: status,
          ));
        }
      }

      emit(ProtegesLoaded(tempList));
    } catch (e) {
      emit(ProtegesLoadFailed(e.toString()));
    }
  }

  Future<void> _onDeleteProtegeRequested(
      DeleteProtegeRequested event, Emitter<UserState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Get current user data for notification
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final currentUserDoc = await currentUserRef.get();
      final currentUserEmail =
          currentUserDoc.data()?['email'] ?? currentUser.email ?? 'A guardian';

      // Get protege data for notification
      final protegeRef =
          FirebaseFirestore.instance.collection('users').doc(event.uidToRemove);
      final protegeDoc = await protegeRef.get();
      final protegeToken = protegeDoc.data()?['token'];

      // Find the protege entry to remove
      final currentProteges = List<Map<String, dynamic>>.from(
          currentUserDoc.data()?['proteges'] ?? []);
      
      final protegeToRemove = currentProteges.firstWhere(
        (protege) => protege['uid'] == event.uidToRemove,
        orElse: () => {},
      );

      if (protegeToRemove.isEmpty) {
        throw Exception("Protege not found");
      }

      // Find the guardian entry to remove from protege's document
      final protegeData = protegeDoc.data();
      final protegeGuardians = List<Map<String, dynamic>>.from(
          protegeData?['guardians'] ?? []);
      
      final guardianToRemove = protegeGuardians.firstWhere(
        (guardian) => guardian['uid'] == currentUser.uid,
        orElse: () => {},
      );

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Remove protege from current user's document
      batch.update(currentUserRef, {
        'proteges': FieldValue.arrayRemove([protegeToRemove])
      });

      // Remove current user as guardian from protege's document
      if (guardianToRemove.isNotEmpty) {
        batch.update(protegeRef, {
          'guardians': FieldValue.arrayRemove([guardianToRemove])
        });
      }

      // Send notification to protege about removal
      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Relationship Ended',
          body: '$currentUserEmail is no longer your guardian',
        );
      }

      // Commit the batch write
      await batch.commit();

      add(FetchProtegesRequested());
    } catch (e) {
      emit(ProtegeDeleteFailed(e.toString()));
    }
  }

  Future<void> _onUpdateFCMTokenRequested(
      UpdateFCMTokenRequested event, Emitter<UserState> emit) async {
    emit(FCMTokenUpdateInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Get the FCM token - either use provided token or get current one
      String? fcmToken = event.token;
      if (fcmToken == null) {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        print("Failed to get FCM token");
        throw Exception("Failed to get FCM token");
      }

      // Update the user's document with the new FCM token
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'token': fcmToken,
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print("FCM Token updated: $fcmToken");
      emit(FCMTokenUpdateSuccess());
    } catch (e) {
      emit(FCMTokenUpdateFailed(e.toString()));
    }
  }

  Future<void> _onUpdateUserRequested(
      UpdateUserRequested event, Emitter<UserState> emit) async {
    emit(UserUpdateInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Get the latest user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User data not found");
      }

      // Create UserModel from the document
      final user = UserModel.fromDocument(userDoc);

      // Update FCM token while we're at it
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'token': fcmToken,
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      // Emit the updated user data
      emit(UserUpdateSuccess(user));
      
      // Also trigger refresh of guardians and proteges lists
      add(FetchGuardiansRequested());
      add(FetchProtegesRequested());
      
    } catch (e) {
      emit(UserUpdateFailed(e.toString()));
    }
  }

  Future<void> _onLoadUserProfile(
      LoadUserProfile event, Emitter<UserState> emit) async {
    emit(UserProfileLoading());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Get the user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User data not found");
      }

      final userData = userDoc.data()!;
      
      emit(UserProfileLoaded(
        name: userData['name'] ?? '',
        email: currentUser.email ?? '',
        phoneNumber: userData['phoneNumber'] ?? '',
        garudId: userData['garudId'] ?? '',
        enableAlerts: userData['enableAlerts'] ?? true,
      ));
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }
}