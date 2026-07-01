// lib/screens/modules_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'finance_screen.dart';
import 'module_items_screen.dart';
import 'activity_screen.dart';
import 'food_screen.dart';
import 'tasks_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({Key? key}) : super(key: key);

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  late Box modulesBox;

  final List<String> defaultModules = [
    'Tarefas',
    'Estudos',
    'Atividade Física',
    'Finanças',
    'Alimentação',
    'Compromissos',
  ];

  @override
  void initState() {
    super.initState();
    modulesBox = Hive.box('alfred_modules');
    if (modulesBox.isEmpty) {
      for (var m in defaultModules) {
        modulesBox.add(m);
      }
    }
  }

  void _addModule() {
    String name = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Adicionar módulo'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Hobbies'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final trimmed = name.trim();
              if (trimmed.isNotEmpty) modulesBox.add(trimmed);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _editModule(dynamic key, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear módulo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Novo nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final trimmed = ctrl.text.trim();
              if (trimmed.isNotEmpty) {
                modulesBox.put(key, trimmed);
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(dynamic key, String moduleName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remover "$moduleName"?'),
        content: const Text('Remover o módulo não apaga os itens existentes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              modulesBox.delete(key);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showModuleOptions(dynamic key, String moduleName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[400], borderRadius: BorderRadius.circular(4)),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('Abrir $moduleName'),
              onTap: () {
                Navigator.pop(context);
                _openModule(moduleName);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Renomear'),
              onTap: () {
                Navigator.pop(context);
                _editModule(key, moduleName);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remover', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemove(key, moduleName);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Roteamento: usa o nome ATUAL salvo no Hive para decidir a tela.
  // Finanças e Atividade Física têm tela dedicada independente do nome exibido,
  // mas como o usuário pode renomear, usamos uma flag separada no futuro.
  // Por ora, roteamos pelo nome original armazenado internamente.
  void _openModule(String moduleName) {
    if (moduleName == 'Finanças') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen()));
    } else if (moduleName == 'Atividade Física' || moduleName == 'Exercício') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityScreen()));
    } else if (moduleName == 'Alimentação') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodScreen()));
    } else if (moduleName == 'Tarefas') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksScreen()));
    
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ModuleItemsScreen(moduleName: moduleName)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos'),
        actions: [
          IconButton(onPressed: _addModule, icon: const Icon(Icons.add)),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: modulesBox.listenable(),
        builder: (context, Box b, _) {
          // Monta lista de {key, name} para manter key estável durante reorder
          final entries = b.keys
              .map((k) => {'key': k, 'name': b.get(k) as String})
              .toList();

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: entries.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              // Lê todos os valores na ordem atual
              final values = entries.map((e) => e['name'] as String).toList();
              final moved = values.removeAt(oldIndex);
              values.insert(newIndex, moved);
              // Apaga tudo e reinserere na nova ordem preservando as keys
              final keys = entries.map((e) => e['key']).toList();
              for (var k in keys) b.delete(k);
              for (var v in values) b.add(v);
              setState(() {});
            },
            itemBuilder: (context, i) {
              final entry = entries[i];
              final key = entry['key'];
              final name = entry['name'] as String;

              return ListTile(
                key: ValueKey(key), // key estável baseada na chave do Hive
                title: Text(name),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Renomear',
                      onPressed: () => _editModule(key, name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Opções',
                      onPressed: () => _showModuleOptions(key, name),
                    ),
                  ],
                ),
                onTap: () => _openModule(name),
              );
            },
          );
        },
      ),
    );
  }
}