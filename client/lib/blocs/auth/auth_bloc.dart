import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:garudclient/repositories/auth_repository.dart';
import 'dart:async';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  late StreamSubscription<User?> _authStateSubscription;

  AuthBloc(this.authRepository) : super(AuthInitial()) {
    // Register all event handlers in the constructor
    
    on<CheckAuthStatus>((event, emit) async {
      emit(AuthLoading());
      try {
        final isLoggedIn = await authRepository.isLoggedIn();
        if (isLoggedIn) {
          emit(AuthSuccess());
        } else {
          emit(AuthInitial());
        }
      } catch (e) {
        emit(AuthFailure(message: e.toString()));
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.login(event.email, event.password);
        emit(AuthSuccess());
      } catch (e) {
        emit(AuthFailure(message: e.toString()));
      }
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.logout();
        emit(AuthInitial());
      } catch (e) {
        emit(AuthFailure(message: e.toString()));
      }
    });

    // Add this to check auth status when bloc initializes
    add(CheckAuthStatus());

    // Listen to Firebase Auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        emit(AuthSuccess());
      } else {
        emit(AuthInitial());
      }
    });
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}