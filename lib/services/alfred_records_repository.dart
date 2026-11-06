import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AlfredRecordsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<void> upsertRecord({
    required String boxName,
    required dynamic hiveKey,
    required dynamic value,
  }) async {
    final hiveKeyText = hiveKey.toString();

    final keyType = hiveKey is int
        ? 'int'
        : hiveKey is double
            ? 'double'
            : 'string';

    final data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{'value': value};

    await _client.from('alfred_records').upsert(
      {
        'box_name': boxName,
        'hive_key': hiveKeyText,
        'key_type': keyType,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'box_name,hive_key',
    );
  }

  Future<void> deleteRecord({
    required String boxName,
    required dynamic hiveKey,
  }) async {
    await _client
        .from('alfred_records')
        .delete()
        .eq('box_name', boxName)
        .eq('hive_key', hiveKey.toString());
  }

  Future<List<Map<String, dynamic>>> getRecords(
    String boxName,
  ) async {
    final response = await _client
        .from('alfred_records')
        .select()
        .eq('box_name', boxName)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }
}