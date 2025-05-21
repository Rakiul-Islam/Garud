import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  ProfileBloc() : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User data not found");
      }      final userData = userDoc.data()!;
      
      emit(ProfileLoaded(
        name: userData['name'] ?? '',
        email: user.email ?? '',
        phoneNumber: userData['phoneNumber'] ?? '',
        garudId: userData['garudId'] ?? '',
        enableAlerts: userData['enableAlerts'] ?? true,
      ));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
