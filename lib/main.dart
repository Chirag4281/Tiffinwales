import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/initialization_service.dart'; // Contains the global navigatorKey
import 'theme/app_theme.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before using platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase and local notifications
  // OneSignal will be initialized after successful login
  try {
    await InitializationService.initializeApp();
    print('✅ App initialization completed successfully');
  } catch (e, stackTrace) {
    print('❌ App initialization failed: $e');
    print(stackTrace);
  }

  runApp(const TiffinWalesApp());
}

class TiffinWalesApp extends StatelessWidget {
  const TiffinWalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TiffinWales',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // 🔥 CRITICAL: Add global navigator key for deep linking from notifications
      navigatorKey: navigatorKey,

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}