import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ModuleItemsScreen extends StatefulWidget {
  final String moduleName;
  const ModuleItemsScreen({Key? key, required this.moduleName}) : super(key: key);

  @override
  State<ModuleItemsScreen> createState() => _ModuleItemsScreenState();
}

class _ModuleItemsScreenState extends State<ModuleItemsScreen> {
  final box = Hive.box('alfred_box');

  void _showAdd() {
    String text = '';
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Adicionar item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(autofocus: true, decoration: const InputDecoration(hintText: 'Descrição'), onChanged: (v) => text = v),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () {
              final title = text.trim();
              if (title.isEmpty) return;
              final item = {
                'title': title,
                'module': widget.moduleName,
                'timestamp': DateTime.now().toIso8601String(),
                'isDone': false,
              };
              final key = DateTime.now().millisecondsSinceEpoch.toString();
              box.put(key, item);
              Navigator.pop(ctx);
            }, child: const Text('Salvar'))),
          ]),
          const SizedBox(height: 18),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.moduleName)),
      floatingActionButton: FloatingActionButton(onPressed: _showAdd, child: const Icon(Icons.add)),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          final keys = b.keys.cast().toList().reversed.toList();
          final filtered = keys.where((k) {
            try {
              final item = Map<String,dynamic>.from(b.get(k) as Map);
              return (item['module'] ?? '') == widget.moduleName;
            } catch (_) {
              return false;
            }
          }).toList();
          if (filtered.isEmpty) return const Center(child: Text('Nenhum item neste módulo.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final key = filtered[i];
              final item = Map<String,dynamic>.from(b.get(key) as Map);
              final title = item['title'] as String? ?? '';
              final isDone = item['isDone'] as bool? ?? false;
              return Dismissible(
                key: Key(key.toString()),
                direction: DismissDirection.endToStart,
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent, child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => b.delete(key),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      final mod = Map<String,dynamic>.from(b.get(key) as Map);
                      mod['isDone'] = !(mod['isDone'] as bool? ?? false);
                      b.put(key, mod);
                    },
                    child: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.green : null),
                  ),
                  title: Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}