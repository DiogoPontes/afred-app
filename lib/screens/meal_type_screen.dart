// lib/screens/meal_type_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MealTypeScreen extends StatefulWidget {
  const MealTypeScreen({Key? key}) : super(key: key);

  @override
  State<MealTypeScreen> createState() => _MealTypeScreenState();
}

class _MealTypeScreenState extends State<MealTypeScreen> {
  final Box _mealTypesBox = Hive.box('meal_types');

  Future<void> _showAddOrEdit({dynamic key}) async {
    final nameCtrl = TextEditingController();
    if (key != null) {
      final existing = _mealTypesBox.get(key) as Map?;
      if (existing != null) {
        nameCtrl.text = existing['name'] ?? '';
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 12),
              Text(
                key == null ? 'Novo tipo de refeição' : 'Editar tipo',
                style: Theme.of(bctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Café da manhã',
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(bctx),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(bctx).showSnackBar(
                          const SnackBar(content: Text('Informe um nome')),
                        );
                        return;
                      }
                      final id = key ?? DateTime.now().millisecondsSinceEpoch.toString();
                      _mealTypesBox.put(id, {
                        'name': name,
                        'updatedAt': DateTime.now().toIso8601String(),
                      });
                      Navigator.pop(bctx);
                      setState(() {});
                    },
                    child: const Text('Salvar'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(dynamic key, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tipo'),
        content: Text('Remover "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _mealTypesBox.delete(key);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    for (var k in _mealTypesBox.keys) {
      final raw = _mealTypesBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        items.add(m);
      }
    }
    items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de Refeição'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const Center(child: Text('Nenhum tipo cadastrado.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final item = items[i];
                final name = item['name'] as String? ?? '';
                return ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showAddOrEdit(key: item['_key']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(item['_key'], name),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}