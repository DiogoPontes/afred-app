import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('alfred_box');
  await Hive.openBox('alfred_sessions');
  await Hive.openBox('alfred_modules');
  await Hive.openBox('alfred_finance_categories');
  runApp(AlfredApp());
}

class AlfredApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alfred',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}