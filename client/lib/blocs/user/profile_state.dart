import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String name;
  final String email;
  final String phoneNumber;
  final String garudId;
  final bool enableAlerts;
  
  const ProfileLoaded({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.garudId,
    required this.enableAlerts,
  });
  
  @override
  List<Object?> get props => [name, email, phoneNumber, garudId, enableAlerts];
}

class ProfileError extends ProfileState {
  final String message;
  
  const ProfileError(this.message);
  
  @override
  List<Object?> get props => [message];
}
