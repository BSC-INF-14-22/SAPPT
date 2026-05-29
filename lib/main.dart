import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_service.dart';
import 'core/services/language_service.dart';

void main() async {
  await FirebaseService.initialize();
  await LanguageService.loadSavedLanguage();
  runApp(const SmartAgriPriceTracker());
}

class SmartAgriPriceTracker extends StatelessWidget {
  const SmartAgriPriceTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Agricultural Price Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.landing,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
