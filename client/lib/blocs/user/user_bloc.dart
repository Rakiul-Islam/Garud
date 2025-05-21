import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitial()) {
    on<AddGuardianRequested>(_onAddGuardianRequested);
    on<FetchGuardiansRequested>(_onFetchGuardiansRequested);
    on<DeleteGuardianRequested>(_onDeleteGuardianRequested);
    on<FetchProtegesRequested>(_onFetchProtegesRequested);
    on<DeleteProtegeRequested>(_onDeleteProtegeRequested);
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

      if (guardianUid == currentUser.uid) {
        throw Exception("You can't add yourself as a guardian");
      }

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Add guardian to current user's document
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      batch.update(currentUserRef, {
        'guardians': FieldValue.arrayUnion([guardianUid])
      });

      // Add current user as protege to guardian's document
      final guardianRef =
          FirebaseFirestore.instance.collection('users').doc(guardianUid);

      batch.update(guardianRef, {
        'proteges': FieldValue.arrayUnion([currentUser.uid])
      });

      // Commit the batch write
      await batch.commit();

      emit(GuardianAdded());
      add(FetchGuardiansRequested()); // refresh list
    } catch (e) {
      emit(GuardianAddFailed(e.toString()));
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

      final guardianUids =
          List<String>.from(userDoc.data()?['guardians'] ?? []);

      List<Map<String, String>> tempList = [];

      for (String uid in guardianUids) {
        final guardianDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (guardianDoc.exists && guardianDoc.data()?['email'] != null) {
          tempList.add({
            'uid': uid,
            'email': guardianDoc.data()!['email'],
          });
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

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Remove guardian from current user's document
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      batch.update(currentUserRef, {
        'guardians': FieldValue.arrayRemove([event.uidToRemove])
      });

      // Remove current user as protege from guardian's document
      final guardianRef =
          FirebaseFirestore.instance.collection('users').doc(event.uidToRemove);

      batch.update(guardianRef, {
        'proteges': FieldValue.arrayRemove([currentUser.uid])
      });

      // Commit the batch write
      await batch.commit();

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

      final protegeUids = List<String>.from(userDoc.data()?['proteges'] ?? []);

      List<Map<String, String>> tempList = [];

      for (String uid in protegeUids) {
        final protegeDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (protegeDoc.exists && protegeDoc.data()?['email'] != null) {
          tempList.add({
            'uid': uid,
            'email': protegeDoc.data()!['email'],
          });
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

      // Use a batch write to update both records atomically
      final batch = FirebaseFirestore.instance.batch();

      // Remove protege from current user's document
      final currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      batch.update(currentUserRef, {
        'proteges': FieldValue.arrayRemove([event.uidToRemove])
      });

      // Remove current user as guardian from protege's document
      final protegeRef =
          FirebaseFirestore.instance.collection('users').doc(event.uidToRemove);

      batch.update(protegeRef, {
        'guardians': FieldValue.arrayRemove([currentUser.uid])
      });

      // Commit the batch write
      await batch.commit();

      add(FetchProtegesRequested());
    } catch (e) {
      emit(ProtegeDeleteFailed(e.toString()));
    }
  }
}
