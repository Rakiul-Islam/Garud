import 'package:equatable/equatable.dart';

abstract class UserState extends Equatable {
  const UserState();
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

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

class GuardianDeleteFailed extends UserState {
  final String message;
  const GuardianDeleteFailed(this.message);
  @override
  List<Object?> get props => [message];
}
