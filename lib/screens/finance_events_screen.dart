import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FinanceEventsScreen extends StatefulWidget {
  const FinanceEventsScreen({
    Key? key,
    required this.onOpenEvent,
  }) : super(key: key);

  final Future<void> Function(String eventId, String eventName) onOpenEvent;

  @override
  State<FinanceEventsScreen> createState() => _FinanceEventsScreenState();
}

class _FinanceEventsScreenState extends State<FinanceEventsScreen> {
  final Box eventsBox = Hive.box('finance_events');
  final Box recordsBox = Hive.box('alfred_box');

  int _recordCount(String eventId) {
    var count = 0;

    for (final raw in recordsBox.values) {
      if (raw is! Map || raw['module'] != 'Finanças') continue;

      final ids = raw['eventIds'];
      if (ids is List && ids.map((id) => id.toString()).contains(eventId)) {
        count++;
      }
    }

    return count;
  }

  Future<void> _editEvent({String? eventId, String? initialName}) async {
    final controller = TextEditingController(text: initialName ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(eventId == null ? 'Criar evento' : 'Renomear evento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Nome do evento',
            hintText: 'Ex.: Viagem para João Pessoa',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(eventId == null ? 'Criar' : 'Salvar'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    final duplicate = eventsBox.keys.any((key) {
      if (eventId != null && key.toString() == eventId) return false;
      final raw = eventsBox.get(key);
      return raw is Map &&
          (raw['name'] as String? ?? '').trim().toLowerCase() ==
              name.toLowerCase();
    });

    if (duplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe um evento com esse nome.')),
      );
      return;
    }

    final id = eventId ?? 'event_${DateTime.now().microsecondsSinceEpoch}';
    final previous = eventId == null ? null : eventsBox.get(eventId);

    await eventsBox.put(id, {
      'id': id,
      'name': name,
      'createdAt': previous is Map
          ? previous['createdAt']
          : DateTime.now().toIso8601String(),
    });
  }

  Future<void> _deleteEvent(String eventId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento?'),
        content: Text(
          'O evento "$name" será excluído. Os registros financeiros serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final key in recordsBox.keys.toList()) {
      final raw = recordsBox.get(key);
      if (raw is! Map || raw['module'] != 'Finanças') continue;

      final item = Map<String, dynamic>.from(raw);
      final rawIds = item['eventIds'];
      if (rawIds is! List) continue;

      final ids = rawIds.map((id) => id.toString()).toList();
      if (ids.remove(eventId)) {
        item['eventIds'] = ids;
        await recordsBox.put(key, item);
      }
    }

    await eventsBox.delete(eventId);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editEvent(),
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: eventsBox.listenable(),
        builder: (context, Box box, _) {
          final events = <Map<String, dynamic>>[];

          for (final key in box.keys) {
            final raw = box.get(key);
            if (raw is Map) {
              final event = Map<String, dynamic>.from(raw);
              event['id'] = (event['id'] ?? key).toString();
              events.add(event);
            }
          }

          events.sort(
            (a, b) => (a['name'] as String? ?? '')
                .toLowerCase()
                .compareTo((b['name'] as String? ?? '').toLowerCase()),
          );

          if (events.isEmpty) {
            return const Center(
              child: Text('Nenhum evento criado. Toque em + para adicionar.'),
            );
          }

          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              final id = event['id'] as String;
              final name = event['name'] as String? ?? 'Evento';

              return ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(name),
                subtitle: Text('${_recordCount(id)} registros'),
                onTap: () async {
                  await widget.onOpenEvent(id, name);
                  if (mounted) setState(() {});
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editEvent(eventId: id, initialName: name);
                    } else if (value == 'delete') {
                      _deleteEvent(id, name);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Renomear')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}