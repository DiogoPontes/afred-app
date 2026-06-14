// lib/screens/home_screen.dart
import 'dart:collection';
import 'focus_screen.dart';
import 'detect_rules_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/alfred_fab.dart';
import 'modules_screen.dart';
import '../services/backup_service.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box box;

  final Map<String, Color> _moduleColors = {
    'Tarefas': Colors.blueGrey,
    'Finanças': Colors.deepOrange,
    'Atividade Física': Colors.green,
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
    final rulesBox = Hive.box('alfred_detect_rules');
    for (var module in rulesBox.keys) {
      final raw = rulesBox.get(module);
      if (raw == null) continue;
      final words = List<String>.from(raw as List);
      for (var word in words) {
        if (lower.contains(word.toLowerCase())) return module as String;
      }
    }
    return 'Tarefas';
  }

  Color _colorForModule(String module) {
    if (_moduleColors.containsKey(module)) return _moduleColors[module]!;
    final palette = [Colors.cyan, Colors.deepPurple, Colors.amber, Colors.lime, Colors.brown];
    return palette[module.hashCode.abs() % palette.length];
  }

  Map<String, dynamic> _parseFinanceFromText(String text) {
    final lower = text.toLowerCase();
    final numMatch = RegExp(r'(?:(?:r\$)\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)').firstMatch(lower);
    double? amount;
    if (numMatch != null) {
      var raw = numMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      amount = double.tryParse(raw);
    }
    String? method;
    if (RegExp(r'\b(cr[eé]dito|credito)\b').hasMatch(lower)) method = 'Crédito';
    else if (RegExp(r'\b(d[eé]bito|debito)\b').hasMatch(lower)) method = 'Débito';
    else if (RegExp(r'\bpix\b').hasMatch(lower)) method = 'Dinheiro/Pix';
    else if (RegExp(r'\btransfer[eê]ncia\b|\btransferencia\b|\btransferir\b').hasMatch(lower)) method = 'Transferência';
    else if (RegExp(r'\bdinheiro\b|\bcash\b').hasMatch(lower)) method = 'Dinheiro/Pix';
    bool? isIncome;
    if (RegExp(r'\b(recebi|ganhei|sal[aá]rio|salario|receita|deposito|dep[oó]sito)\b').hasMatch(lower)) isIncome = true;
    if (RegExp(r'\b(gastei|paguei|pagar|comprei|gasto|gastar)\b').hasMatch(lower)) isIncome = false;
    return {'amount': amount, 'paymentMethod': method, 'isIncome': isIncome};
  }

  List<String> _availableModules() {
    final defaults = ['Tarefas', 'Finanças', 'Atividade Física', 'Alimentação', 'Estudos', 'Compromissos'];
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

  List<Map<String, dynamic>> _availableActivities() {
    final activitiesBox = Hive.box('activities');
    final out = <Map<String, dynamic>>[];
    for (var k in activitiesBox.keys) {
      final raw = activitiesBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        out.add(m);
      }
    }
    out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  void _showQuickAdd() {
    final categoriesBox = Hive.box('alfred_finance_categories');
    final activitiesBox = Hive.box('activities');
    final logsBox = Hive.box('activity_logs');

    String detectedModule = 'Tarefas';
    String selectedModule = detectedModule;
    bool manuallySelected = false;

    // ── controllers ─────────────────────────────────────────────────────────
    final textCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    bool descriptionManuallyEdited = false;

    // ── campos finanças ──────────────────────────────────────────────────────
    bool financeIsIncome = false;
    final financeAmountCtrl = TextEditingController();
    String financeCategory = '(Sem categoria)';
    String financePaymentMethod = 'Dinheiro/Pix';
    final financeInstallmentsCtrl = TextEditingController(text: '1');
    DateTime financeDate = DateTime.now();
    bool financeAmountAutoFilled = false;
    bool financeMethodManuallyEdited = false;
    final paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];
    final incomeMethods = ['Transferência', 'PIX', 'Dinheiro'];

    // ── campos atividade física ──────────────────────────────────────────────
    final activities = _availableActivities();
    String? actSelectedKey = activities.isNotEmpty ? activities.first['_key'] as String : null;
    String actSelectedName = activities.isNotEmpty ? activities.first['name'] as String : '';
    String actSelectedUnit = activities.isNotEmpty ? (activities.first['unit'] as String? ?? 'min') : 'min';
    final actDurationCtrl = TextEditingController();
    final actDistanceCtrl = TextEditingController();
    final actCaloriesCtrl = TextEditingController();
    final actNotesCtrl = TextEditingController();
    String actIntensity = 'Moderado';
    DateTime actDate = DateTime.now();

    List<String> _financeCategories() {
      final set = <String>{'(Sem categoria)'};
      for (var v in categoriesBox.values) {
        if (v is String && v.trim().isNotEmpty) set.add(v.trim());
      }
      return set.toList()..sort();
    }

    String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

    List<String> modules() {
      final m = _availableModules();
      if (!m.contains(selectedModule)) m.insert(0, selectedModule);
      return m;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          if (!manuallySelected) {
            detectedModule = detectModule(textCtrl.text);
            selectedModule = detectedModule;
          }
          final isFinance = selectedModule.toLowerCase() == 'finanças';
          final isActivity = selectedModule.toLowerCase() == 'atividade física';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // handle
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  Text('Adicionar rapidamente',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  // ── campo de texto livre (detecção) ──────────────────────
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Gastei 50 no almoço',
                      labelText: 'Texto',
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        detectedModule = detectModule(val);
                        if (!manuallySelected) selectedModule = detectedModule;

                        // sincroniza descrição apenas se não foi editada manualmente
                        if (!descriptionManuallyEdited) {
                          descriptionCtrl.text = val;
                        }

                        // parse finanças
                        final parsed = _parseFinanceFromText(val);
                        final double? amt = parsed['amount'] as double?;
                        final String? pm = parsed['paymentMethod'] as String?;
                        final bool? inc = parsed['isIncome'] as bool?;
                        if (amt != null &&
                            (financeAmountCtrl.text.isEmpty || financeAmountAutoFilled)) {
                          financeAmountCtrl.text = amt.toStringAsFixed(2);
                          financeAmountAutoFilled = true;
                        }
                        if (pm != null && !financeMethodManuallyEdited) {
                          financePaymentMethod = (inc == true)
                              ? (incomeMethods.contains(pm) ? pm : incomeMethods.first)
                              : (paymentMethods.contains(pm) ? pm : paymentMethods.first);
                        }
                        if (inc != null) {
                          financeIsIncome = inc;
                          if (financeIsIncome) {
                            if (!incomeMethods.contains(financePaymentMethod))
                              financePaymentMethod = incomeMethods.first;
                          } else {
                            if (!paymentMethods.contains(financePaymentMethod))
                              financePaymentMethod = paymentMethods.first;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── seletor de módulo ────────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade600),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: _colorForModule(selectedModule).withOpacity(0.9),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(selectedModule,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setModalState(() {
                        manuallySelected = false;
                        selectedModule = detectedModule;
                        financeMethodManuallyEdited = false;
                      }),
                      child: const Text('Usar sugestão'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: modules().contains(selectedModule)
                            ? selectedModule
                            : modules().first,
                        items: modules()
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Row(children: [
                                    Container(
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                          color: _colorForModule(m).withOpacity(0.9),
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(m),
                                  ]),
                                ))
                            .toList(),
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
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── FINANÇAS ─────────────────────────────────────────────
                  if (isFinance) ...[
                    DropdownButtonFormField<String>(
                      value: financeIsIncome ? 'Receita' : 'Despesa',
                      items: const [
                        DropdownMenuItem(value: 'Despesa', child: Text('Despesa')),
                        DropdownMenuItem(value: 'Receita', child: Text('Receita')),
                      ],
                      onChanged: (v) => setModalState(() {
                        financeIsIncome = (v == 'Receita');
                        if (financeIsIncome) {
                          financePaymentMethod = incomeMethods.first;
                          financeInstallmentsCtrl.text = '1';
                          financeMethodManuallyEdited = false;
                        } else {
                          if (financePaymentMethod == incomeMethods.first)
                            financePaymentMethod = paymentMethods.first;
                          financeMethodManuallyEdited = false;
                        }
                      }),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 8),

                    // ── Descrição independente do texto livre ────────────
                    TextField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      onChanged: (_) => descriptionManuallyEdited = true,
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: financeAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valor (Ex: 45.00)'),
                      onChanged: (_) => financeAmountAutoFilled = false,
                    ),
                    const SizedBox(height: 8),
                    if (!financeIsIncome) ...[
                      DropdownButtonFormField<String>(
                        value: financeCategory,
                        items: _financeCategories()
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setModalState(
                            () => financeCategory = v ?? '(Sem categoria)'),
                        decoration: const InputDecoration(labelText: 'Categoria'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    DropdownButtonFormField<String>(
                      value: financePaymentMethod,
                      items: (financeIsIncome ? incomeMethods : paymentMethods)
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        financePaymentMethod = v ?? financePaymentMethod;
                        financeMethodManuallyEdited = true;
                        if (!financeIsIncome && financePaymentMethod != 'Crédito')
                          financeInstallmentsCtrl.text = '1';
                      }),
                      decoration:
                          const InputDecoration(labelText: 'Método de pagamento'),
                    ),
                    const SizedBox(height: 8),
                    if (!financeIsIncome && financePaymentMethod == 'Crédito') ...[
                      TextField(
                        controller: financeInstallmentsCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Número de parcelas'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: financeDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (picked != null)
                          setModalState(() => financeDate = DateTime(
                              picked.year, picked.month, picked.day,
                              financeDate.hour, financeDate.minute));
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Data: ${_formatDate(financeDate)}'),
                    ),
                    const SizedBox(height: 12),

                  // ── ATIVIDADE FÍSICA ─────────────────────────────────────
                  ] else if (isActivity) ...[
                    DropdownButtonFormField<String?>(
                      value: actSelectedKey,
                      items: [
                        if (activities.isEmpty)
                          const DropdownMenuItem(
                              value: null,
                              child: Text('Nenhuma atividade definida')),
                        ...activities.map((a) => DropdownMenuItem(
                            value: a['_key'] as String,
                            child: Text(a['name']))),
                      ],
                      onChanged: (v) => setModalState(() {
                        actSelectedKey = v;
                        if (v != null) {
                          final a = activitiesBox.get(v) as Map?;
                          if (a != null) {
                            actSelectedName = a['name'] ?? actSelectedName;
                            actSelectedUnit = a['unit'] ?? actSelectedUnit;
                          }
                        }
                      }),
                      decoration: const InputDecoration(labelText: 'Atividade'),
                    ),
                    const SizedBox(height: 8),
                    if (actSelectedUnit == 'min') ...[
                      TextField(
                        controller: actDurationCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Duração (minutos)'),
                      ),
                    ] else ...[
                      TextField(
                        controller: actDistanceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Distância (km)'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: actCaloriesCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Calorias (opcional)'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: actIntensity,
                      items: const [
                        DropdownMenuItem(value: 'Leve', child: Text('Leve')),
                        DropdownMenuItem(value: 'Moderado', child: Text('Moderado')),
                        DropdownMenuItem(value: 'Intenso', child: Text('Intenso')),
                      ],
                      onChanged: (v) =>
                          setModalState(() => actIntensity = v ?? 'Moderado'),
                      decoration: const InputDecoration(labelText: 'Intensidade'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: actNotesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Notas (opcional)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: actDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (picked != null)
                          setModalState(() => actDate = DateTime(
                              picked.year, picked.month, picked.day,
                              actDate.hour, actDate.minute));
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Data: ${_formatDate(actDate)}'),
                    ),
                    const SizedBox(height: 12),

                  // ── OUTROS MÓDULOS ───────────────────────────────────────
                  ] else ...[
                    // ── Descrição independente do texto livre ────────────
                    TextField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      onChanged: (_) => descriptionManuallyEdited = true,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Escolher data (opcional)'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── botões Cancelar / Salvar ─────────────────────────────
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                      onPressed: () {
                        // usa descriptionCtrl para o título salvo
                        final text = descriptionCtrl.text.trim().isNotEmpty
                            ? descriptionCtrl.text.trim()
                            : textCtrl.text.trim();

                        // ── salvar finanças ────────────────────────────────
                        if (isFinance) {
                          final amount = double.tryParse(
                                  financeAmountCtrl.text.replaceAll(',', '.')) ??
                              0.0;
                          final installments =
                              int.tryParse(financeInstallmentsCtrl.text.trim()) ?? 1;
                          final count = installments < 1 ? 1 : installments;
                          final categoryValue = financeIsIncome
                              ? 'Receita'
                              : (financeCategory == '(Sem categoria)'
                                  ? ''
                                  : financeCategory);

                          if (count <= 1) {
                            box.add({
                              'title': text.isEmpty
                                  ? (financeIsIncome ? 'Receita' : 'Despesa')
                                  : text,
                              'module': 'Finanças',
                              'timestamp': financeDate.toIso8601String(),
                              'isDone': false,
                              'amount': amount,
                              'category': categoryValue,
                              'paymentMethod': financePaymentMethod,
                              'isIncome': financeIsIncome,
                            });
                          } else {
                            final groupId =
                                DateTime.now().millisecondsSinceEpoch.toString();
                            for (int i = 0; i < count; i++) {
                              final due = DateTime(financeDate.year,
                                  financeDate.month + i, financeDate.day);
                              box.add({
                                'title':
                                    '${text.isEmpty ? (financeIsIncome ? 'Receita' : 'Despesa') : text} (${i + 1}/$count)',
                                'module': 'Finanças',
                                'timestamp': due.toIso8601String(),
                                'isDone': false,
                                'amount': _installmentAmount(amount, count, i),
                                'category': categoryValue,
                                'installmentTotal': count,
                                'installmentNumber': i + 1,
                                'installmentGroupId': groupId,
                                'originalAmount': amount,
                                'paymentMethod': financePaymentMethod,
                                'isIncome': financeIsIncome,
                              });
                            }
                          }

                        // ── salvar atividade física ────────────────────────
                        } else if (isActivity) {
                          final name = actSelectedName.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Selecione uma atividade')));
                            return;
                          }
                          final duration = double.tryParse(
                                  actDurationCtrl.text.replaceAll(',', '.')) ??
                              0.0;
                          final distance = double.tryParse(
                                  actDistanceCtrl.text.replaceAll(',', '.')) ??
                              0.0;
                          final calories = double.tryParse(
                                  actCaloriesCtrl.text.replaceAll(',', '.')) ??
                              0.0;

                          final logKey =
                              DateTime.now().millisecondsSinceEpoch.toString();

                          logsBox.put(logKey, {
                            'activityKey': actSelectedKey,
                            'activityName': name,
                            'unit': actSelectedUnit,
                            'durationMinutes':
                                actSelectedUnit == 'min' ? duration : null,
                            'distanceKm':
                                actSelectedUnit == 'km' ? distance : null,
                            'calories': calories > 0 ? calories : null,
                            'intensity': actIntensity,
                            'notes': actNotesCtrl.text.trim(),
                            'timestamp': actDate.toIso8601String(),
                            'createdAt': DateTime.now().toIso8601String(),
                          });

                          String sub = '';
                          if (actSelectedUnit == 'min' && duration > 0)
                            sub =
                                '${duration.toStringAsFixed(0)} min • $actIntensity';
                          if (actSelectedUnit == 'km' && distance > 0)
                            sub =
                                '${distance.toStringAsFixed(2)} km • $actIntensity';
                          if (calories > 0)
                            sub += ' • ${calories.toStringAsFixed(0)} kcal';

                          box.put('activity_$logKey', {
                            'title': '$name${sub.isNotEmpty ? ' — $sub' : ''}',
                            'module': 'Atividade Física',
                            'timestamp': actDate.toIso8601String(),
                            'isDone': false,
                            'activityLogKey': logKey,
                            'activityName': name,
                            'unit': actSelectedUnit,
                            'durationMinutes':
                                actSelectedUnit == 'min' ? duration : null,
                            'distanceKm':
                                actSelectedUnit == 'km' ? distance : null,
                            'calories': calories > 0 ? calories : null,
                            'intensity': actIntensity,
                            'notes': actNotesCtrl.text.trim(),
                          });

                        // ── salvar outros módulos ──────────────────────────
                        } else {
                          if (text.isEmpty) return;
                          box.put(
                              DateTime.now().millisecondsSinceEpoch.toString(),
                              {
                                'title': text,
                                'module': selectedModule.isEmpty
                                    ? '(Sem módulo)'
                                    : selectedModule,
                                'timestamp': DateTime.now().toIso8601String(),
                                'isDone': false,
                              });
                        }

                        Navigator.of(context).pop();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Salvar'),
                    )),
                  ]),
                  const SizedBox(height: 18),
                ],
              ),
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
    final keyStr = key.toString();
    if (keyStr.startsWith('activity_')) {
      final logKey = keyStr.replaceFirst('activity_', '');
      Hive.box('activity_logs').delete(logKey);
    }
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro'),
        content: const Text('Deseja excluir este registro permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _deleteItem(key);
              Navigator.of(ctx).pop();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _itemsForToday(Box b) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
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
      } catch (_) {}
    }
    items.sort(
        (a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE, d MMMM', 'pt_BR').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
              Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
            ]),
        actions: [
          IconButton(
            tooltip: 'Copiar backup',
            icon: const Icon(Icons.copy_all),
            onPressed: () async {
              final json = BackupService.exportBackupJson();
              await Clipboard.setData(ClipboardData(text: json));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup copiado para a área de transferência')),
              );
            },
          ),
          IconButton(
            tooltip: 'Restaurar backup',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              await BackupService.restoreFromAsset('assets/backups/dev_backup.json');
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup restaurado com sucesso')),
              );
            },
          ),
          IconButton(
            tooltip: 'Módulos',
            icon: const Icon(Icons.view_list),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModulesScreen())),
          ),
          IconButton(
            tooltip: 'Regras de detecção',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DetectRulesScreen())),
          ),
          IconButton(
              tooltip: 'Relatório',
              icon: const Icon(Icons.bar_chart_outlined),
              onPressed: () {}),
          IconButton(
            tooltip: 'Foco',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FocusScreen(
                  taskTitle: 'Estudar Álgebra — Capítulo 3',
                  demoMode: true),
            )),
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                      'Nenhum registro para hoje. Toque em + para adicionar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                ),
              );
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
                final timeLabel =
                    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      leading: GestureDetector(
                        onTap: () => _toggleDone(key),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isDone ? Colors.green : Colors.transparent,
                            border: Border.all(
                                color: isDone
                                    ? Colors.green
                                    : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : const Icon(Icons.circle_outlined, size: 20),
                        ),
                      ),
                      title: Text(title,
                          style: TextStyle(
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isDone
                                ? Colors.grey
                                : Theme.of(context).textTheme.bodyLarge!.color,
                            fontWeight: FontWeight.w600,
                          )),
                      subtitle: Row(children: [
                        Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: _colorForModule(module),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(module),
                        // ── exibe valor e tipo se for Finanças ──
                        if (module == 'Finanças') ...[
                          const SizedBox(width: 8),
                          const Text('•'),
                          const SizedBox(width: 8),
                          Builder(builder: (_) {
                            final isIncome = item['isIncome'] as bool? ?? false;
                            final amount = item['amount'] as double? ?? 0.0;
                            final formatted = NumberFormat.currency(
                                locale: 'pt_BR', symbol: 'R\$').format(amount);
                            return Text(
                              '${isIncome ? '▲ ' : '▼ '}$formatted',
                              style: TextStyle(
                                color: isIncome ? Colors.green : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            );
                          }),
                        ],
                      ]),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(timeLabel,
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(key)),
                          ]),
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

  double _installmentAmount(double total, int count, int index) {
    if (count <= 1) return total;
    final base = double.parse((total / count).toStringAsFixed(2));
    if (index < count - 1) return base;
    return double.parse((total - base * (count - 1)).toStringAsFixed(2));
  }
}