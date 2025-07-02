// blocs/user/user_state.dart :
import 'package:equatable/equatable.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/data/models/user_model.dart';

abstract class UserState extends Equatable {
  const UserState();
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

// Guardian States
class GuardianAddInProgress extends UserState {}

class GuardianAdded extends UserState {}

class GuardianAddFailed extends UserState {
  final String message;
  const GuardianAddFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class GuardiansLoadInProgress extends UserState {}

class GuardiansLoaded extends UserState {
  final List<PublicUserModel> guardians;
  const GuardiansLoaded(this.guardians);
  @override
  List<Object?> get props => [guardians];
}

class GuardianLoadFailed extends UserState {
  final String message;
  const GuardianLoadFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class GuardianDeleteFailed extends UserState {
  final String message;
  const GuardianDeleteFailed(this.message);
  @override
  List<Object?> get props => [message];
}

// Protege States
class ProtegesLoadInProgress extends UserState {}

class ProtegesLoaded extends UserState {
  final List<PublicUserModel> proteges;
  const ProtegesLoaded(this.proteges);
  @override
  List<Object?> get props => [proteges];
}

class ProtegesLoadFailed extends UserState {
  final String message;
  const ProtegesLoadFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class ProtegeDeleteFailed extends UserState {
  final String message;
  const ProtegeDeleteFailed(this.message);
  @override
  List<Object?> get props => [message];
}

// New states for accept/reject functionality
class ProtegeAcceptFailed extends UserState {
  final String message;
  const ProtegeAcceptFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class ProtegeRejectFailed extends UserState {
  final String message;
  const ProtegeRejectFailed(this.message);
  @override
  List<Object?> get props => [message];
}

// States for FCM token update
class FCMTokenUpdateInProgress extends UserState {}

class FCMTokenUpdateSuccess extends UserState {}

class FCMTokenUpdateFailed extends UserState {
  final String message;
  const FCMTokenUpdateFailed(this.message);
  @override
  List<Object?> get props => [message];
}

// States for complete user data update
class UserUpdateInProgress extends UserState {}

class UserUpdateSuccess extends UserState {
  final UserModel user;
  const UserUpdateSuccess(this.user);
  @override
  List<Object?> get props => [user];
}

class UserUpdateFailed extends UserState {
  final String message;
  const UserUpdateFailed(this.message);
  @override
  List<Object?> get props => [message];
}

// States for user profile data loading
class UserProfileLoading extends UserState {}

class UserProfileLoaded extends UserState {
  final String name;
  final String email;
  final String phoneNumber;
  final String garudId;
  final bool enableAlerts;
  
  const UserProfileLoaded({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.garudId,
    required this.enableAlerts,
  });
  
  @override
  List<Object?> get props => [name, email, phoneNumber, garudId, enableAlerts];
}

class UserProfileError extends UserState {
  final String message;
  
  const UserProfileError(this.message);
  
  @override
  List<Object?> get props => [message];
}