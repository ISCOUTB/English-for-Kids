import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/session_storage.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/home/home_screen.dart';

class EnglishForKidsApp extends StatefulWidget {
  const EnglishForKidsApp({super.key});

  @override
  State<EnglishForKidsApp> createState() => _EnglishForKidsAppState();
}

class _EnglishForKidsAppState extends State<EnglishForKidsApp> {
  late final ApiClient _api;
  late final SessionStorage _storage;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _storage = SessionStorage();
    _auth = AuthController(
      api: _api,
      service: AuthService(_api),
      storage: _storage,
    );
    _auth.bootstrap();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English for Kids',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) {
          return switch (_auth.status) {
            AuthStatus.loading => const SplashScreen(),
            AuthStatus.signedOut => LoginScreen(auth: _auth),
            AuthStatus.signedIn =>
              HomeScreen(auth: _auth, api: _api, storage: _storage),
          };
        },
      ),
    );
  }
}
