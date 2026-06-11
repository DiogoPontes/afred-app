import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'finance_screen.dart';
import 'module_items_screen.dart';

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
    'Exercício',
    'Finanças',
    'Alimentação',
    'Compromissos'
  ];

  @override
  void initState() {
    super.initState();
    modulesBox = Hive.box('alfred_modules');
    // seed defaults if empty
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
              if (trimmed.isNotEmpty) {
                modulesBox.add(trimmed);
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Adicionar'),
          )
        ],
      ),
    );
  }

  void _openModule(String moduleName) {
    if (moduleName == 'Finanças') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen()));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModuleItemsScreen(moduleName: moduleName)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos'),
        actions: [
          IconButton(onPressed: _addModule, icon: const Icon(Icons.add))
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: modulesBox.listenable(),
        builder: (context, Box b, _) {
          final modules = b.values.cast<String>().toList();
          return ListView.separated(
            itemCount: modules.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = modules[i];
              return ListTile(
                title: Text(m),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openModule(m),
                onLongPress: () {
                  // delete module
                  showDialog(context: context, builder: (_) {
                    return AlertDialog(
                      title: Text('Remover "$m"?'),
                      content: const Text('Remover o módulo não apaga os itens existentes.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        ElevatedButton(onPressed: () {
                          // remove first occurrence
                          final key = b.keys.firstWhere((k) => b.get(k) == m);
                          b.delete(key);
                          Navigator.pop(context);
                          setState(() {});
                        }, child: const Text('Remover')),
                      ],
                    );
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}