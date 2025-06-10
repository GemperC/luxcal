import 'package:LuxCal/core/config/app_router.dart';
import 'package:LuxCal/core/theme/theme.dart';
import 'package:LuxCal/firebase_options.dart';
import 'package:LuxCal/src/blocs/auth/auth_bloc.dart';
import 'package:LuxCal/src/blocs/auth_screen/auth_screen_cubit.dart';
import 'package:LuxCal/src/blocs/calendar/calendar_bloc.dart';
import 'package:LuxCal/src/repositories/auth_repo.dart';
import 'package:LuxCal/src/repositories/user_repo.dart';
import 'package:LuxCal/src/services/fcm.dart';
import 'package:LuxCal/src/utils/messenger.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

final GetIt getIt = GetIt.instance;
void setupLocator() {
  getIt.registerLazySingleton<UserRepository>(() => UserRepository());
  getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepository(userRepository: getIt<UserRepository>()));

  getIt.registerLazySingleton<AuthBloc>(() => AuthBloc(
        authRepository: getIt<AuthRepository>(),
        userRepository: getIt<UserRepository>(),
      ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final fcm = FCM();

  await Future.delayed(Duration(seconds: 1));
  await fcm.getNotificationPermissions();

  await GetStorage.init();
  setupLocator();

  runApp(RestartWidget(child: const MyApp()));
}

class RestartWidget extends StatefulWidget {
  RestartWidget({required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()!.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final storage = GetStorage();
  @override
  void initState() {
    super.initState();
    _setupNotificationHandlers();
  }

  void _setupNotificationHandlers() {
    // Handle notification when app is opened from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from notification: ${message.messageId}');
        // Handle the notification
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: getIt<UserRepository>()),
        RepositoryProvider.value(value: getIt<AuthRepository>()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => getIt<AuthBloc>(),
          ),
          BlocProvider<AuthScreenCubit>(
            create: (context) => AuthScreenCubit(
              authRepository: getIt<AuthRepository>(),
            ),
          ),
          BlocProvider<CalendarBloc>(
            create: (context) => CalendarBloc(),
          ),
        ],
        child: MaterialApp.router(
          scaffoldMessengerKey: Utils.messengerKey,
          debugShowCheckedModeBanner: false,
          title: 'LuxCal',
          theme: AppTheme.mainTheme,
          routerConfig: router,
        ),
      ),
    );
  }
}
