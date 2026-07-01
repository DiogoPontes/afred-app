// lib/screens/workout_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  final Box _plansBox = Hive.box('workout_plans');

  static const List<String> _allMuscleGroups = [
    'Peito',
    'Costas',
    'Ombro',
    'Bíceps',
    'Tríceps',
    'Antebraço',
    'Abdômen',
    'Oblíquo',
    'Quadríceps',
    'Posterior de coxa',
    'Glúteo',
    'Panturrilha',
    'Trapézio',
    'Lombar',
  ];

  List<Map<String, dynamic>> _getPlans() {
    final out = <Map<String, dynamic>>[];
    for (var k in _plansBox.keys) {
      final raw = _plansBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        out.add(m);
      }
    }
    out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  Future<void> _showAddOrEdit({Map<String, dynamic>? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final List<String> selectedGroups = existing != null
        ? List<String>.from(existing['muscleGroups'] as List? ?? [])
        : [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bctx) {
        return StatefulBuilder(builder: (bctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(bctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // handle
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4))),

                  Text(
                      existing == null ? 'Novo treino' : 'Editar treino',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Nome do treino
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome do treino',
                      hintText: 'Ex: Treino A — Peito e Tríceps',
                      prefixIcon: Icon(Icons.edit_note),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grupos musculares
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Grupos musculares',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _allMuscleGroups.map((group) {
                      final selected = selectedGroups.contains(group);
                      return FilterChip(
                        label: Text(group),
                        selected: selected,
                        onSelected: (val) => setModal(() {
                          if (val) {
                            selectedGroups.add(group);
                          } else {
                            selectedGroups.remove(group);
                          }
                        }),
                        selectedColor:
                            Theme.of(bctx).colorScheme.primaryContainer,
                        checkmarkColor:
                            Theme.of(bctx).colorScheme.primary,
                      );
                    }).toList(),
                  ),

                  if (selectedGroups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(bctx)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${selectedGroups.length} grupo(s): ${selectedGroups.join(', ')}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(bctx).colorScheme.primary),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(bctx),
                            child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Informe um nome para o treino')));
                          return;
                        }
                        if (selectedGroups.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Selecione ao menos um grupo muscular')));
                          return;
                        }
                        final key = existing?['_key'] ??
                            DateTime.now()
                                .millisecondsSinceEpoch
                                .toString();
                        _plansBox.put(key, {
                          'name': name,
                          'muscleGroups': selectedGroups,
                          'createdAt': existing?['createdAt'] ??
                              DateTime.now().toIso8601String(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        });
                        Navigator.pop(bctx);
                        setState(() {});
                      },
                    )),
                  ]),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          );
        });
      },
    );
    setState(() {});
  }

  Future<void> _confirmDelete(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Excluir treino'),
        content: Text('Excluir "${plan['name']}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true) {
      _plansBox.delete(plan['_key']);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _getPlans();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos de Musculação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo treino',
            onPressed: () => _showAddOrEdit(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Novo treino'),
      ),
      body: plans.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_gymnastics,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Nenhum treino cadastrado',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text('Toque em "Novo treino" para começar',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final plan = plans[i];
                final groups =
                    List<String>.from(plan['muscleGroups'] as List? ?? []);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.sports_gymnastics,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(plan['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Editar',
                              onPressed: () =>
                                  _showAddOrEdit(existing: plan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.redAccent),
                              tooltip: 'Excluir',
                              onPressed: () => _confirmDelete(plan),
                            ),
                          ]),
                          if (groups.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: groups
                                  .map((g) => Chip(
                                        label: Text(g,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withOpacity(0.5),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ]),
                  ),
                );
              },
            ),
    );
  }
}