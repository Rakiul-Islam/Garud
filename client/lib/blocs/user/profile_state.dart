import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String email;
  final String garudId;
  
  const ProfileLoaded({
    required this.email,
    required this.garudId,
  });
  
  @override
  List<Object?> get props => [email, garudId];
}

class ProfileError extends ProfileState {
  final String message;
  
  const ProfileError(this.message);
  
  @override
  List<Object?> get props => [message];
}
