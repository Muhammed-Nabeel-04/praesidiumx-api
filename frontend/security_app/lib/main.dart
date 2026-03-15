import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiConfig.init();

  runApp(const SecurityApp());
}

class SecurityApp extends StatelessWidget {
  const SecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
