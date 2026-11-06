import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class AssetRestore {
  static const String _assetPath = 'assets/backups/dev_backup.json';

  /// Restaura o backup incluído nos assets apenas se as caixas estiverem vazias.
  static Future<void> restoreIfEmpty() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(_assetPath);
    } catch (e) {
      debugPrint('AssetRestore: não foi possível ler $_assetPath: $e');
      return;
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AssetRestore: JSON inválido: $e');
      return;
    }

    final boxes = decoded['boxes'];
    if (boxes is! Map<String, dynamic>) return;

    int restaurados = 0;

    for (final entry in boxes.entries) {
      final String boxName = entry.key;
      final List records = entry.value as List? ?? [];
      if (records.isEmpty) continue;

      final Box box;
      try {
        box = Hive.box(boxName);
      } catch (e) {
        debugPrint('AssetRestore: box "$boxName" não está aberto: $e');
        continue;
      }

      if (box.isNotEmpty) continue; // não sobrescreve dados existentes

      for (final rec in records) {
        if (rec is! Map) continue;
        final dynamic rawKey = rec['key'];
        final String keyType = rec['keyType']?.toString() ?? 'string';

        dynamic key = rawKey;
        if (keyType == 'int') {
          key = int.parse(rawKey.toString());
        } else if (keyType == 'double') {
          key = double.parse(rawKey.toString());
        }

        await box.put(key, rec['value']);
        restaurados++;
      }

      debugPrint('AssetRestore: box "$boxName" restaurado (${records.length} registro(s)).');
    }

    debugPrint('AssetRestore concluído: $restaurados registro(s) restaurados dos assets.');
  }
}