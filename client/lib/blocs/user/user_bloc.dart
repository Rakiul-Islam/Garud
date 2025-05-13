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
  }

  Future<void> _onAddGuardianRequested(
      AddGuardianRequested event, Emitter<UserState> emit) async {
    emit(GuardianAddInProgress());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'guardians': FieldValue.arrayUnion([guardianUid])
      });

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
        final guardianDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (guardianDoc.exists && guardianDoc.data()?['email'] != null) {
          tempList.add({
            'uid': uid,
            'email': guardianDoc.data()!['email'],
          });
        }
      }

      emit(GuardiansLoaded(tempList));
    } catch (e) {
      emit(GuardianAddFailed(e.toString()));
    }
  }

  Future<void> _onDeleteGuardianRequested(
      DeleteGuardianRequested event, Emitter<UserState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'guardians': FieldValue.arrayRemove([event.uidToRemove])
      });

      add(FetchGuardiansRequested());
    } catch (e) {
      emit(GuardianDeleteFailed(e.toString()));
    }
  }
}
