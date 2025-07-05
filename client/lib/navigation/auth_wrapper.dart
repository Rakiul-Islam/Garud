import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/auth/auth_bloc.dart';
import 'package:garudclient/blocs/auth/auth_state.dart';
import 'package:garudclient/screens/home_page.dart';
import 'package:garudclient/screens/login_page.dart';
import 'package:garudclient/services/notification_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize notifications with context (only once)
    Future.microtask(() async {
      if (!_initialized) {
        await NotificationService.initialize(context);
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
          return HomePage(user: state.user);
        } else if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          return LoginPage();
        }
      },
    );
  }
}
