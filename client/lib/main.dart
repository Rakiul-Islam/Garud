import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'services/notification_service.dart';
import 'repositories/auth_repository.dart';
import 'blocs/auth/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Register background message handler before initializing notifications
  FirebaseMessaging.onBackgroundMessage(NotificationService.handleBackgroundMessage);
  
  await NotificationService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthRepository _authRepository = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
  providers: [
    BlocProvider<AuthBloc>(create: (_) => AuthBloc(_authRepository)),
    BlocProvider<UserBloc>(create: (_) => UserBloc()),
  ],
  child: MaterialApp(
        title: 'Garud',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: LoginPage(),
      ),
);
  }
}
