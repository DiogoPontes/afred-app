import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'modules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box'); // já deveria ter sido aberto em main.dart
  }

  String detectModule(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'gastei|r\$|reais|paguei|pagar|comprei').hasMatch(lower)) {
      return 'Finanças';
    } else if (RegExp(r'corri|treino|academia|km|corrida|muscula').hasMatch(lower)) {
      return 'Exercício';
    } else if (RegExp(r'comi|almoç|jantar|lanche|pizza|refei').hasMatch(lower)) {
      return 'Alimentação';
    } else if (RegExp(r'estud|prova|revisar|aula|curso').hasMatch(lower)) {
      return 'Estudos';
    } else if (RegExp(r'reuni|médic|dentista|encontro|agenda').hasMatch(lower)) {
      return 'Compromissos';
    }
    return 'Tarefas';
  }

  void _showQuickAdd() {
    String text = '';
    String detectedModule = 'Tarefas';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4)),
                ),
                const Text(
                  'Adicionar rapidamente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  decoration:
                      const InputDecoration(hintText: 'Ex: Gastei 50 no almoço'),
                  onChanged: (val) {
                    setModalState(() {
                      text = val;
                      detectedModule = detectModule(val);
                    });
                  },
                  onSubmitted: (_) {
                    // optional: submit on enter
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      label: Text(detectedModule,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.blue.shade50,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final title = text.trim();
                          if (title.isEmpty) return;
                          final key =
                              DateTime.now().millisecondsSinceEpoch.toString();
                          final item = {
                            'title': title,
                            'module': detectedModule,
                            'timestamp': DateTime.now().toIso8601String(),
                            'isDone': false,
                          };
                          box.put(key, item);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        });
      },
    );
  }

  void _toggleDone(dynamic key) {
    final Map item = Map<String, dynamic>.from(box.get(key));
    item['isDone'] = !(item['isDone'] as bool);
    box.put(key, item);
  }

  void _deleteItem(dynamic key) {
    box.delete(key);
  }

  List<Map<String, dynamic>> _itemsForToday(Box b) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final List<Map<String, dynamic>> items = [];

    for (var key in b.keys) {
      try {
        final raw = b.get(key);
        if (raw == null) continue;
        final item = Map<String, dynamic>.from(raw as Map);

        // aceita int (msSinceEpoch), String (ISO) ou DateTime
        DateTime? ts;
        final t = item['timestamp'];
        if (t == null) continue;
        if (t is int) {
          ts = DateTime.fromMillisecondsSinceEpoch(t);
        } else if (t is String) {
          ts = DateTime.tryParse(t);
        } else if (t is DateTime) {
          ts = t;
        }

        if (ts == null) continue;
        ts = ts.toLocal();

        if (ts.isBefore(start) || ts.isAfter(end)) continue;

        final copy = Map<String, dynamic>.from(item);
        copy['_key'] = key;
        copy['_ts'] = ts;
        items.add(copy);
      } catch (_) {
        // ignora entradas inválidas
        continue;
      }
    }

    // ordena por timestamp decrescente (mais recente primeiro)
    items.sort((a, b) {
      final ta = a['_ts'] as DateTime;
      final tb = b['_ts'] as DateTime;
      return tb.compareTo(ta);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alfred - Hoje'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Módulos',
            icon: const Icon(Icons.view_list),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModulesScreen())),
          ),
          // mantêm os outros ícones (Relatório/Foco) se quiser
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          final items = _itemsForToday(b);
          if (items.isEmpty) {
            return const Center(
                child: Text('Nenhum registro para hoje. Toque em + para adicionar.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = items[index];
              final key = item['_key'];
              final title = item['title'] as String? ?? '';
              final module = item['module'] as String? ?? '';
              final isDone = item['isDone'] as bool? ?? false;
              final ts = item['_ts'] as DateTime;
              final timeLabel = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

              return Dismissible(
                key: Key(key.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteItem(key),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () => _toggleDone(key),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green : Colors.transparent,
                        border: Border.all(
                            color: isDone ? Colors.green : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : const Icon(Icons.circle_outlined, size: 20),
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                        decoration:
                            isDone ? TextDecoration.lineThrough : TextDecoration.none,
                        color: isDone ? Colors.grey : Colors.black,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(module),
                  trailing: Text(timeLabel,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    // future: open detail / edit
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}