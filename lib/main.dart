import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/alfred_theme.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/asset_restore.dart';
import 'services/data_sync_service.dart';
import 'screens/login_screen.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  await Hive.initFlutter();

  await Hive.openBox('alfred_box');
  await Hive.openBox('alfred_sessions');
  await Hive.openBox('alfred_modules');
  await Hive.openBox('alfred_finance_categories');
  await Hive.openBox('cards');

  await Hive.openBox('activities');
  await Hive.openBox('activity_logs');
  await Hive.openBox('workout_plans');

  await Hive.openBox('alfred_reading_books');
  await Hive.openBox('alfred_reading_activities');

  await Hive.openBox('alfred_detect_rules');
  await Hive.openBox('meal_types');

  await Hive.openBox('alfred_study_types');
  await Hive.openBox('alfred_study_activities');
  await Hive.openBox('alfred_study_schedules');
  await Hive.openBox('alfred_study_disciplines');

  await Hive.openBox('investments');
  await Hive.openBox('investment_categories');

  await Hive.openBox('alfred_shopping_products');
  await Hive.openBox('alfred_shopping_list');
  await Hive.openBox('alfred_shopping_saved');
  await Hive.openBox('finance_events');
  
  await initializeDateFormatting('pt_BR');

  await NotificationService.init();
  await NotificationService.rescheduleStudyNotifications();

 
  
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
      theme: alfredTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  bool _loggedIn = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loggedIn = SupabaseService.isLoggedIn;

    if (_loggedIn) {
      _prepareData();
    } else {
      _ready = true;
    }

    _authSubscription = SupabaseService.authStateChanges.listen((state) async {
      final loggedIn = state.session?.user != null;

      if (loggedIn && !_loggedIn) {
        if (mounted) {
          setState(() {
            _loggedIn = true;
            _ready = false;
          });
        }
        await _prepareData();
      } else if (!loggedIn && _loggedIn) {
        if (mounted) {
          setState(() {
            _loggedIn = false;
            _ready = true;
          });
        }
      }
    });
  }

  Future<void> _prepareData() async {
    final userId = SupabaseService.currentUserId;
    debugPrint('AuthGate: usuário atual = $userId');

    if (userId == null) {
      debugPrint('AuthGate: sessão ainda não disponível.');
      if (mounted) {
        setState(() {
          _loggedIn = false;
          _ready = true;
        });
      }
      return;
    }

    final sync = DataSyncService();
    debugPrint('AuthGate: iniciando hidratação dos dados...');
    await sync.hydrateFromSupabase();
    sync.startWatching();

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const HomeScreen() : const LoginScreen();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}