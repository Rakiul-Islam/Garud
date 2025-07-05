// blocs/user/user_bloc.dart :
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:garudclient/services/fcm_service.dart';
import 'package:garudclient/repositories/user_repository.dart';

import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final FCMService _fcmService;
  final UserRepository _userRepository;

  UserBloc({
    required UserRepository userRepository,
    required FCMService fcmService,
  })  : _userRepository = userRepository,
        _fcmService = fcmService,
        super(UserInitial()) {
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
      final guardianDoc = await _userRepository.findUserByEmail(event.guardianEmail);
      final guardianUid = guardianDoc.id;

      // Get current user data for notification
      final currentUserDoc = await _userRepository.getUserData(currentUser.uid);
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserEmail =
          currentUserData?['email'] ?? currentUser.email ?? 'A user';

      // Check if guardian already exists or is already requested
      final currentGuardians = List<Map<String, dynamic>>.from(
          currentUserData?['guardians'] ?? []);
      
      final existingGuardian = currentGuardians.firstWhere(
        (guardian) => guardian['uid'] == guardianUid,
        orElse: () => {},
      );

      if (existingGuardian.isNotEmpty) {
        throw Exception("Guardian already exists or request already sent");
      }

      await _userRepository.addGuardian(currentUser.uid, guardianUid);

      // Send notification to the guardian
      final guardianData = guardianDoc.data() as Map<String, dynamic>?;
      final guardianToken = guardianData?['token'];

      if (guardianToken != null) {
        await _fcmService.sendNotification(
          targetToken: guardianToken,
          title: 'Guardian Request',
          body: '$currentUserEmail wants to add you as their guardian',
          data: {
            'type': 'protege_related',
          },
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

      await _userRepository.acceptGuardian(currentUser.uid, event.protegeUid);

      // Send notification to protege
      final protegeDoc = await _userRepository.getUserData(event.protegeUid);
      final protegeData = protegeDoc.data() as Map<String, dynamic>?;
      final protegeToken = protegeData?['token'];

      final currentUserDoc = await _userRepository.getUserData(currentUser.uid);
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserEmail = currentUserData?['email'] ?? 'Guardian';

      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Request Accepted',
          body: '$currentUserEmail has accepted your guardian request',
          data: {"type": "guardian_related"},
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

      await _userRepository.rejectGuardian(currentUser.uid, event.protegeUid);

      // Send notification to protege
      final protegeDoc = await _userRepository.getUserData(event.protegeUid);
      final protegeData = protegeDoc.data() as Map<String, dynamic>?;
      final protegeToken = protegeData?['token'];

      final currentUserDoc = await _userRepository.getUserData(currentUser.uid);
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserEmail = currentUserData?['email'] ?? 'Guardian';

      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Request Rejected',
          body: '$currentUserEmail has rejected your guardian request',
          data: {"type": "guardian_related"},
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

      final guardians = await _userRepository.getGuardians(currentUser.uid);
      emit(GuardiansLoaded(guardians));
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
      final currentUserDoc = await _userRepository.getUserData(currentUser.uid);
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserEmail =
          currentUserData?['email'] ?? currentUser.email ?? 'A protege';

      // Get guardian data for notification
      final guardianDoc = await _userRepository.getUserData(event.uidToRemove);
      final guardianData = guardianDoc.data() as Map<String, dynamic>?;
      final guardianToken = guardianData?['token'];

      await _userRepository.deleteGuardian(currentUser.uid, event.uidToRemove);

      // Send notification to guardian about removal
      if (guardianToken != null) {
        await _fcmService.sendNotification(
          targetToken: guardianToken,
          title: 'Guardian Relationship Ended',
          body: '$currentUserEmail has removed you as their guardian',
          data: {"type": "protege_related"},
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

      final proteges = await _userRepository.getProteges(currentUser.uid);
      emit(ProtegesLoaded(proteges));
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
      final currentUserDoc = await _userRepository.getUserData(currentUser.uid);
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final currentUserEmail =
          currentUserData?['email'] ?? currentUser.email ?? 'A guardian';

      // Get protege data for notification
      final protegeDoc = await _userRepository.getUserData(event.uidToRemove);
      final protegeData = protegeDoc.data() as Map<String, dynamic>?;
      final protegeToken = protegeData?['token'];

      await _userRepository.deleteProtege(currentUser.uid, event.uidToRemove);

      // Send notification to protege about removal
      if (protegeToken != null) {
        await _fcmService.sendNotification(
          targetToken: protegeToken,
          title: 'Guardian Relationship Ended',
          body: '$currentUserEmail is no longer your guardian',
          data: {"type": "guardian_related"},
        );
      }

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

      await _userRepository.updateFCMToken(currentUser.uid, fcmToken);
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

      // Update FCM token while we're at it
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      final user = await _userRepository.updateUser(currentUser.uid, fcmToken);

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
      final userDoc = await _userRepository.getUserProfile(currentUser.uid);

      if (!userDoc.exists) {
        throw Exception("User data not found");
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
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