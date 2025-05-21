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

// New event for fetching proteges
class FetchProtegesRequested extends UserEvent {}

class DeleteProtegeRequested extends UserEvent {
  final String uidToRemove;
  const DeleteProtegeRequested(this.uidToRemove);
  @override
  List<Object> get props => [uidToRemove];
}