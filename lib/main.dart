// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/alfred_theme.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // inicializa Hive e boxes (mantendo seu layout original)
  await Hive.initFlutter();
  await Hive.openBox('alfred_box');
  await Hive.openBox('alfred_sessions');
  await Hive.openBox('alfred_modules');
  await Hive.openBox('alfred_finance_categories');
  await Hive.openBox('cards');
  await Hive.openBox('activities'); 
  await Hive.openBox('activity_logs');
  await Hive.openBox('alfred_detect_rules');
  await Hive.openBox('workout_plans');
  await Hive.openBox('meal_types');

  // inicializa locales para DateFormat (pt_BR)
  await initializeDateFormatting('pt_BR');

  runApp(const AlfredApp());
}

class AlfredApp extends StatelessWidget {
  const AlfredApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alfred',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: alfredTheme, // seu theme customizado (alfred_theme.dart)
      home: const SplashScreen(),
      
    );
  }
}