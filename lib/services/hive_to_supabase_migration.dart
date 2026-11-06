import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_service.dart';

class HiveToSupabaseMigration {
  static const List<String> boxNames = [
    'alfred_box',
    'alfred_sessions',
    'alfred_modules',
    'alfred_finance_categories',
    'cards',
    'activities',
    'activity_logs',
    'workout_plans',
    'alfred_reading_books',
    'alfred_reading_activities',
    'alfred_detect_rules',
    'meal_types',
    'alfred_study_types',
    'alfred_study_activities',
    'alfred_study_schedules',
    'alfred_study_disciplines',
    'investments',
    'investment_categories',
  ];

  Future<void> migrateAll() async {
    final client = SupabaseService.client;
    int total = 0;

    for (final boxName in boxNames) {
      final Box box = Hive.box(boxName);
      final List<Map<String, dynamic>> rows = [];

      for (final key in box.keys) {
        final dynamic value = box.get(key);
        if (value == null) continue;

        rows.add({
          'box_name': boxName,
          'hive_key': key.toString(),
          'key_type': key is int
              ? 'int'
              : key is double
                  ? 'double'
                  : 'string',
          'data': _sanitize(value),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (rows.isEmpty) {
        debugPrint('Migração: box "$boxName" está vazio.');
        continue;
      }

      try {
        await client
            .from('alfred_records')
            .upsert(rows, onConflict: 'box_name,hive_key');
        total += rows.length;
        debugPrint(
            'Migração: box "$boxName" enviou ${rows.length} registro(s).');
      } catch (e) {
        debugPrint('Migração: erro no box "$boxName": $e');
      }
    }

    debugPrint('Migração concluída: $total registro(s) enviados ao Supabase.');
  }

  dynamic _sanitize(dynamic value) {
    return jsonDecode(
      jsonEncode(value, toEncodable: (dynamic object) {
        if (object is DateTime) return object.toIso8601String();
        return object.toString();
      }),
    );
  }
}