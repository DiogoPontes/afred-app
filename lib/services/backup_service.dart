// lib/services/backup_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

class BackupService {
  BackupService._();

  /// Boxes incluídas no backup.
  /// IMPORTANTE: sempre que criar uma box nova no app,
  /// adicione o nome dela nesta lista.
  static const List<String> _boxNames = [
    'alfred_box',
    'alfred_study_types',
    'alfred_study_activities',
    'alfred_study_schedules',
    'alfred_study_disciplines',
    'alfred_reading_books',
    'alfred_reading_activities',
    'activity_logs',
    'meal_types',
    'activities',
    'cards',
    'workout_plans',
    'alfred_finance_categories',
    'alfred_shopping_products',
    'alfred_shopping_list',
    'alfred_shopping_saved',
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // Export
  // ═══════════════════════════════════════════════════════════════════════

  static Future<String> exportBackupJson() async {
    final boxes = <String, dynamic>{};

    for (final name in _boxNames) {
      final box = await _openBox(name);

      final entries = <String, dynamic>{};
      for (final key in box.keys) {
        entries[_encodeKey(key)] = box.get(key);
      }

      boxes[name] = entries;
    }

    final payload = <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes,
    };

    return jsonEncode(payload);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Restore
  // ═══════════════════════════════════════════════════════════════════════

  static Future<Map<String, int>> restoreFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('boxes')) {
      throw const FormatException('Backup inválido.');
    }

    final boxes = decoded['boxes'] as Map<String, dynamic>;

    var boxCount = 0;
    var recordCount = 0;

    for (final name in _boxNames) {
      final rawEntries = boxes[name];
      if (rawEntries == null) continue;

      final entries = (rawEntries as Map).cast<String, dynamic>();
      final box = await _openBox(name);

      await box.clear();

      for (final entry in entries.entries) {
        await box.put(_decodeKey(entry.key), entry.value);
        recordCount++;
      }

      boxCount++;
    }

    debugPrint(
      'Restore concluído: $boxCount box(es) e $recordCount registro(s).',
    );

    return {'boxes': boxCount, 'records': recordCount};
  }

  static Future<void> restoreFromAsset(String path) async {
    final json = await rootBundle.loadString(path);
    await restoreFromJson(json);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════

  static Future<Box> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return Hive.openBox(name);
  }

  /// Codifica a chave junto com o tipo, para restaurar com o tipo correto.
  /// Ex.: chave int 3 → "int|3"; chave String "study_done_5_20260909"
  /// → "String|study_done_5_20260909".
  static String _encodeKey(dynamic key) => '${key.runtimeType}|$key';

  static dynamic _decodeKey(String encoded) {
    final separator = encoded.indexOf('|');

    // Compatibilidade com backups antigos, sem prefixo de tipo.
    if (separator < 0) {
      return int.tryParse(encoded) ?? encoded;
    }

    final type = encoded.substring(0, separator);
    final value = encoded.substring(separator + 1);

    switch (type) {
      case 'int':
        return int.tryParse(value) ?? value;
      case 'double':
        return double.tryParse(value) ?? value;
      default:
        return value;
    }
  }
}