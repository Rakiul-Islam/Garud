import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // <- NEW
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/user/user_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'config/theme_config.dart';
import 'navigation/auth_wrapper.dart';
import 'repositories/auth_repository.dart';
import 'repositories/user_repository.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env.appwrite file
  // await dotenv.load(fileName: ".env.appwrite"); 

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Register background message handler before initializing notifications
  FirebaseMessaging.onBackgroundMessage(NotificationService.handleBackgroundMessage);

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final AuthRepository _authRepository = AuthRepository();
  final UserRepository _userRepository = UserRepository();
  final FCMService _fcmService = FCMService();
  final SharedPreferences prefs;

  MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(_authRepository)),
        BlocProvider<UserBloc>(
          create: (_) => UserBloc(
            userRepository: _userRepository,
            fcmService: _fcmService,
          ),
        ),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc(prefs)),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Garud',
            theme: ThemeConfig.lightTheme,
            darkTheme: ThemeConfig.darkTheme,
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            // home: CriminalDetailsPage(documentId: "435173B"),
            home: AuthWrapper(),
          );
        },
      ),
    );
  }
}
