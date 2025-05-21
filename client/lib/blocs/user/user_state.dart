import 'package:equatable/equatable.dart';

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
  final List<Map<String, String>> guardians;
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
  final List<Map<String, String>> proteges;
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