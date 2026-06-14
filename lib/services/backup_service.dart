import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackupService {
  static const List<String> boxNames = [
    'alfred_box',
    'alfred_sessions',
    'alfred_modules',
    'alfred_finance_categories',
    'cards',
    'activities',
    'activity_logs',
    'alfred_detect_rules',
  ];

  static Map<String, dynamic> exportBackupMap() {
    final result = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': <String, dynamic>{},
    };

    final boxesMap = result['boxes'] as Map<String, dynamic>;

    for (final boxName in boxNames) {
      final box = Hive.box(boxName);
      final entries = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        final value = box.get(key);
        entries.add({
          'key': key,
          'value': _normalize(value),
        });
      }

      boxesMap[boxName] = entries;
    }

    return result;
  }

  static String exportBackupJson({bool pretty = true}) {
    final data = exportBackupMap();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  static Future<void> restoreFromJsonString(
    String jsonString, {
    bool clearBeforeRestore = true,
  }) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final boxes = Map<String, dynamic>.from(decoded['boxes'] as Map);

    for (final boxName in boxNames) {
      final box = Hive.box(boxName);

      if (clearBeforeRestore) {
        await box.clear();
      }

      final rawEntries = (boxes[boxName] as List?) ?? const [];

      for (final raw in rawEntries) {
        final entry = Map<String, dynamic>.from(raw as Map);
        await box.put(entry['key'], _denormalize(entry['value']));
      }
    }
  }

  static Future<void> restoreFromAsset(
    String assetPath, {
    bool clearBeforeRestore = true,
  }) async {
    final jsonString = await rootBundle.loadString(assetPath);
    await restoreFromJsonString(
      jsonString,
      clearBeforeRestore: clearBeforeRestore,
    );
  }

  static dynamic _normalize(dynamic value) {
    if (value is DateTime) {
      return {
        '__type': 'datetime',
        'value': value.toIso8601String(),
      };
    }

    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _normalize(val)));
    }

    if (value is List) {
      return value.map(_normalize).toList();
    }

    return value;
  }

  static dynamic _denormalize(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      if (map['__type'] == 'datetime') {
        return DateTime.parse(map['value'] as String);
      }

      return map.map((key, val) => MapEntry(key, _denormalize(val)));
    }

    if (value is List) {
      return value.map(_denormalize).toList();
    }

    return value;
  }
}