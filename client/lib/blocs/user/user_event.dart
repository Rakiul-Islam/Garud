// blocs/user/user_event.dart :
import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  @override
  List<Object> get props => [];
}

class AddGuardianRequested extends UserEvent {
  final String guardianEmail;
  const AddGuardianRequested(this.guardianEmail);
  @override
  List<Object> get props => [guardianEmail];
}

class FetchGuardiansRequested extends UserEvent {}

class DeleteGuardianRequested extends UserEvent {
  final String uidToRemove;
  const DeleteGuardianRequested(this.uidToRemove);
  @override
  List<Object> get props => [uidToRemove];
}

class FetchProtegesRequested extends UserEvent {}

class DeleteProtegeRequested extends UserEvent {
  final String uidToRemove;
  const DeleteProtegeRequested(this.uidToRemove);
  @override
  List<Object> get props => [uidToRemove];
}

// New events for accepting/rejecting guardian requests
class AcceptGuardianRequested extends UserEvent {
  final String protegeUid;
  const AcceptGuardianRequested(this.protegeUid);
  @override
  List<Object> get props => [protegeUid];
}

class RejectGuardianRequested extends UserEvent {
  final String protegeUid;
  const RejectGuardianRequested(this.protegeUid);
  @override
  List<Object> get props => [protegeUid];
}

// Event for updating FCM token
class UpdateFCMTokenRequested extends UserEvent {
  final String? token;
  const UpdateFCMTokenRequested({this.token});
  @override
  List<Object> get props => [token ?? ''];
}

// Event for updating complete user data
class UpdateUserRequested extends UserEvent {}

// Event for loading user profile data
class LoadUserProfile extends UserEvent {}