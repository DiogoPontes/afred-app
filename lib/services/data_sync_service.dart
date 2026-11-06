import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'supabase_service.dart';

class DataSyncService {
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
    'finance_events',
  ];

  final List<StreamSubscription<BoxEvent>> _subscriptions = [];

  /// Carrega os dados do Supabase para as caixas Hive.
  ///
  /// O box é limpo SEMPRE antes de popular: o Supabase é a fonte da verdade.
  /// Dados locais que não existem na nuvem pertencem a outra sessão/usuário
  /// e não devem sobreviver à hidratação.
  Future<void> hydrateFromSupabase() async {
    print('========== INÍCIO DA HIDRATAÇÃO V3 ==========');

    final client = SupabaseService.client;
    final session = client.auth.currentSession;
    final currentUser = client.auth.currentUser;
    final userId = currentUser?.id;

    print('Sync V3: currentUser.id = ${currentUser?.id}');
    print('Sync V3: session.user.id = ${session?.user.id}');
    print('Sync V3: user_id usado na consulta = $userId');
    print('Sync V3: sessão existe = ${session != null}');

    if (userId == null || session == null) {
      print('Sync V3: sessão ou usuário não disponível.');
      print('========== FIM DA HIDRATAÇÃO V3 ==========');
      return;
    }

    try {
      final allRows = await client
          .from('alfred_records')
          .select('box_name, hive_key, user_id')
          .eq('user_id', userId);

      print(
        'Sync V3: total geral encontrado para o usuário = ${allRows.length}',
      );

      if (allRows.isNotEmpty) {
        print('Sync V3: primeiro registro encontrado = ${allRows.first}');
      }
    } catch (e, stackTrace) {
      print('Sync V3: erro na consulta geral = $e');
      print(stackTrace);
    }

    for (final boxName in boxNames) {
      try {
        print('Sync V3: consultando box "$boxName"...');

        final rows = await client
            .from('alfred_records')
            .select('hive_key, key_type, data')
            .eq('box_name', boxName)
            .eq('user_id', userId);

        final box = Hive.box(boxName);

        // Limpa SEMPRE (antes era limpo só quando havia registros remotos).
        // Se a consulta falhar, o catch abaixo preserva o box; mas se ela
        // retornar vazia, significa que esta conta não possui registros —
        // qualquer dado local é resquício de outra sessão e deve ser
        // descartado.
        await box.clear();

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final key = _parseKey(row['hive_key'], row['key_type']);
          await box.put(key, row['data']);
        }

        print(
          'Sync V3: box "$boxName" hidratado com '
          '${rows.length} registro(s).',
        );
      } catch (e, stackTrace) {
        print('Sync V3: erro ao hidratar "$boxName": $e');
        print(stackTrace);
      }
    }

    print('========== FIM DA HIDRATAÇÃO V3 ==========');
  }

  /// Espelha qualquer alteração nas caixas Hive para o Supabase.
  void startWatching() {
    for (final boxName in boxNames) {
      final Box box = Hive.box(boxName);

      _subscriptions.add(
        box.watch().listen((BoxEvent event) {
          _mirrorEvent(boxName, event);
        }),
      );
    }

    debugPrint(
      'Sync: espelhamento ativo (${boxNames.length} box(es) monitorados).',
    );
  }

  Future<void> _mirrorEvent(String boxName, BoxEvent event) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      return;
    }

    try {
      if (event.deleted) {
        await client
            .from('alfred_records')
            .delete()
            .eq('box_name', boxName)
            .eq('hive_key', event.key.toString())
            .eq('user_id', userId);

        return;
      }

      await client.from('alfred_records').upsert(
        {
          'box_name': boxName,
          'hive_key': event.key.toString(),
          'key_type': _keyType(event.key),
          'data': _sanitize(event.value),
          'user_id': userId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'box_name,hive_key,user_id',
      );
    } catch (e) {
      debugPrint('Sync: erro ao espelhar "$boxName/${event.key}": $e');
    }
  }

  dynamic _parseKey(dynamic rawKey, dynamic keyType) {
    final type = keyType?.toString() ?? 'string';

    if (type == 'int') {
      return int.parse(rawKey.toString());
    }

    if (type == 'double') {
      return double.parse(rawKey.toString());
    }

    return rawKey.toString();
  }

  String _keyType(dynamic key) {
    if (key is int) {
      return 'int';
    }

    if (key is double) {
      return 'double';
    }

    return 'string';
  }

  dynamic _sanitize(dynamic value) {
    return jsonDecode(
      jsonEncode(
        value,
        toEncodable: (dynamic object) {
          if (object is DateTime) {
            return object.toIso8601String();
          }

          return object.toString();
        },
      ),
    );
  }
}