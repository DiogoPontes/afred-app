// lib/screens/home_screen.dart
import 'dart:collection';
import 'focus_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/alfred_fab.dart';
import 'modules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box box;

  // mapa de cores sutis por módulo
  final Map<String, Color> _moduleColors = {
    'Tarefas': Colors.blueGrey,
    'Finanças': Colors.deepOrange,
    'Exercício': Colors.green,
    'Alimentação': Colors.pink,
    'Estudos': Colors.indigo,
    'Compromissos': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box'); 
  }

  String detectModule(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'gastei|r\$|reais|paguei|pagar|comprei').hasMatch(lower)) {
      return 'Finanças';
    } else if (RegExp(r'corri|treino|academia|km|corrida|malhei|muscula').hasMatch(lower)) {
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

  Color _colorForModule(String module) {
    if (_moduleColors.containsKey(module)) {
      return _moduleColors[module]!;
    }
    final palette = [Colors.cyan, Colors.deepPurple, Colors.amber, Colors.lime, Colors.brown];
    final idx = module.hashCode.abs() % palette.length;
    return palette[idx];
  }

  List<String> _availableModules() {
    final defaults = ['Tarefas', 'Finanças', 'Exercício', 'Alimentação', 'Estudos', 'Compromissos'];
    final LinkedHashSet<String> set = LinkedHashSet<String>.from(defaults);

    for (var key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;
        final item = Map<String, dynamic>.from(raw as Map);
        final m = (item['module'] as String?)?.trim();
        if (m != null && m.isNotEmpty) set.add(m);
      } catch (_) {}
    }
    return set.toList();
  }

  void _showQuickAdd() {
    String text = '';
    String detectedModule = 'Tarefas';
    String selectedModule = detectedModule;
    bool manuallySelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final currentModules = _availableModules();

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
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(4)),
                ),
                Text('Adicionar rapidamente', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Ex: Gastei 50 no almoço'),
                  onChanged: (val) {
                    setModalState(() {
                      text = val;
                      final newDetected = detectModule(val);
                      detectedModule = newDetected;
                      if (!manuallySelected) {
                        selectedModule = newDetected;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Módulo atual com ponto colorido (sem o chip de sugestão)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade600),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _colorForModule(selectedModule).withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(selectedModule, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          selectedModule = detectedModule;
                          manuallySelected = false;
                        });
                      },
                      child: const Text('Usar sugestão'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedModule,
                        items: currentModules.map((m) => DropdownMenuItem(
                          value: m,
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: _colorForModule(m).withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(m),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() {
                            selectedModule = v;
                            manuallySelected = true;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Trocar módulo',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        text.isEmpty ? 'Nenhuma descrição' : text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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
                          final key = DateTime.now().millisecondsSinceEpoch.toString();
                          final item = {
                            'title': title,
                            'module': selectedModule,
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
    final raw = box.get(key);
    if (raw == null) return;
    final Map item = Map<String, dynamic>.from(raw as Map);
    item['isDone'] = !(item['isDone'] as bool);
    box.put(key, item);
  }

  void _deleteItem(dynamic key) {
    box.delete(key);
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Excluir registro'),
          content: const Text('Deseja excluir este registro permanentemente?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                _deleteItem(key);
                Navigator.of(ctx).pop();
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
        DateTime? ts;
        final t = item['timestamp'];
        if (t == null) continue;
        if (t is int) ts = DateTime.fromMillisecondsSinceEpoch(t);
        else if (t is String) ts = DateTime.tryParse(t);
        else if (t is DateTime) ts = t;

        if (ts == null) continue;
        ts = ts.toLocal();
        if (ts.isBefore(start) || ts.isAfter(end)) continue;

        final copy = Map<String, dynamic>.from(item);
        copy['_key'] = key;
        copy['_ts'] = ts;
        items.add(copy);
      } catch (_) { continue; }
    }
    items.sort((a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM', 'pt_BR').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
          Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          IconButton(
            tooltip: 'Módulos', icon: const Icon(Icons.view_list),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModulesScreen())),
          ),
          IconButton(tooltip: 'Relatório', icon: const Icon(Icons.bar_chart_outlined), onPressed: () {}),
          IconButton(
                tooltip: 'Foco',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FocusScreen(
                        taskTitle: 'Estudar Álgebra — Capítulo 3',
                        demoMode: true,
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
      floatingActionButton: AlfredFab(onTap: _showQuickAdd),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box b, _) {
            final items = _itemsForToday(b);
            if (items.isEmpty) {
              return Center(child: Padding(padding: const EdgeInsets.all(20),
                  child: Text('Nenhum registro para hoje. Toque em + para adicionar.', 
                  style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center)));
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
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: GestureDetector(
                        onTap: () => _toggleDone(key),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isDone ? Colors.green : Colors.transparent,
                            border: Border.all(color: isDone ? Colors.green : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isDone ? const Icon(Icons.check, color: Colors.white, size: 20) : const Icon(Icons.circle_outlined, size: 20),
                        ),
                      ),
                      title: Text(title, style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge!.color,
                            fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _colorForModule(module), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(module),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(key)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}