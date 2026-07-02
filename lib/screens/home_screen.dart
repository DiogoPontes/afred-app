// lib/screens/home_screen.dart
import 'dart:collection';
import 'focus_screen.dart';
import 'detect_rules_screen.dart';
import 'workout_plan_screen.dart';
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
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  final Map<String, Color> _moduleColors = {
    'Tarefas': Colors.blueGrey,
    'Finanças': Colors.deepOrange,
    'Atividade Física': Colors.green,
    'Alimentação': Colors.pink,
    'Estudos': Colors.indigo,
    'Compromissos': Colors.teal,
  };

  final Map<String, IconData> _moduleIcons = {
    'Tarefas': Icons.check_circle_outline,
    'Finanças': Icons.payments_outlined,
    'Atividade Física': Icons.fitness_center_outlined,
    'Alimentação': Icons.restaurant_outlined,
    'Estudos': Icons.book_outlined,
    'Compromissos': Icons.calendar_today_outlined,
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

  IconData _iconForModule(String module) {
    if (_moduleIcons.containsKey(module)) return _moduleIcons[module]!;
    return Icons.category_outlined;
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Alta':
        return Colors.redAccent;
      case 'Média':
        return Colors.amber;
      case 'Baixa':
      default:
        return Colors.green;
    }
  }

  Widget _moduleIconCircle(String module, {double size = 44, double iconSize = 20}) {
    final color = _colorForModule(module);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(_iconForModule(module), color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _buildCheckOrIcon(Map<String, dynamic> item, bool isDone) {
    final module = item['module'] as String? ?? '';
    if (isDone) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Center(child: Icon(Icons.check, color: Colors.white, size: 20)),
      );
    } else {
      return _moduleIconCircle(module, size: 44, iconSize: 20);
    }
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

  String? _extractDescriptionFromText(String text) {
    String cleaned = text.toLowerCase();

    cleaned = cleaned.replaceAll(
      RegExp(r'(?:(?:r\$)\s*)?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?'),
      ' ',
    );

    final wordsToRemove = [
      'gastei', 'paguei', 'pagar', 'comprei', 'gasto', 'gastar', 'gastos',
      'recebi', 'ganhei', 'salário', 'salario', 'receita', 'deposito', 'depósito',
      'crédito', 'credito', 'débito', 'debito', 'pix', 'transferência',
      'transferencia', 'transferir', 'dinheiro', 'cash', 'reais', 'real',
      'no', 'na', 'do', 'da', 'em', 'de', 'por', 'com', 'pelo', 'pela',
      'a', 'o', 'as', 'os', 'um', 'uma', 'uns', 'umas', 'para', 'pra',
    ];

    for (final word in wordsToRemove) {
      cleaned = cleaned.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b'), ' ');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) return null;

    return cleaned.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
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

  List<String> _activeCardNames() {
    final names = <String>['(Nenhum)'];
    try {
      final cBox = Hive.box('cards');
      for (var key in cBox.keys) {
        final raw = cBox.get(key);
        if (raw == null) continue;
        if (raw is Map) {
          final card = Map<dynamic, dynamic>.from(raw);
          final isActive = card['isActive'] == true || card['isActive'] == null;
          final name = card['name']?.toString();
          if (isActive && name != null && name.isNotEmpty) {
            names.add(name);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao ler cartões: $e');
    }
    return names;
  }

  void _showQuickAdd() {
    final categoriesBox = Hive.box('alfred_finance_categories');
    final activitiesBox = Hive.box('activities');
    final logsBox = Hive.box('activity_logs');
    final cardsBox = Hive.box('cards');
    final workoutPlansBox = Hive.box('workout_plans');

    String detectedModule = 'Tarefas';
    String selectedModule = detectedModule;
    bool manuallySelected = false;

    final textCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    bool descriptionManuallyEdited = false;

    // FINANÇAS
    bool financeIsIncome = false;
    final financeAmountCtrl = TextEditingController();
    String financeCategory = '(Sem categoria)';
    String financePaymentMethod = 'Dinheiro/Pix';
    final financeInstallmentsCtrl = TextEditingController(text: '1');
    DateTime financeDate = DateTime.now();
    TimeOfDay financeTime = TimeOfDay.now();
    bool financeAmountAutoFilled = false;
    bool financeMethodManuallyEdited = false;
    final paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];
    final incomeMethods = ['Transferência', 'PIX', 'Dinheiro'];
    String? selectedFinanceCard = '(Nenhum)';

    // ATIVIDADE FÍSICA
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
    TimeOfDay actTime = TimeOfDay.now(); // <-- adicionado: horário
    bool actIsDone = false; // <-- adicionado: marcado como realizado
    // Novos: treino selecionado (para musculação)
    String? selectedWorkoutPlanKey;
    String? selectedWorkoutPlanName;

    // ALIMENTAÇÃO
    final mealTypesBox = Hive.box('meal_types');
    List<Map<String, dynamic>> availableMealTypes() {
      final out = <Map<String, dynamic>>[];
      for (var k in mealTypesBox.keys) {
        final raw = mealTypesBox.get(k);
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          m['_key'] = k;
          out.add(m);
        }
      }
      out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return out;
    }

    final foodTypes = availableMealTypes();
    String? foodSelectedTypeKey = foodTypes.isNotEmpty ? foodTypes.first['_key'] as String : null;
    String foodSelectedTypeName = foodTypes.isNotEmpty ? foodTypes.first['name'] as String : '';
    final foodDescCtrl = TextEditingController();
    DateTime foodDate = DateTime.now();
    TimeOfDay foodTime = TimeOfDay.now();
    bool foodIsDone = false;

    List<String> financeCategories() {
      final set = <String>{'(Sem categoria)'};
      for (var v in categoriesBox.values) {
        if (v is String && v.trim().isNotEmpty) set.add(v.trim());
      }
      return set.toList()..sort();
    }

    String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

    List<String> modules() {
      final m = _availableModules();
      if (!m.contains(selectedModule)) m.insert(0, selectedModule);
      return m;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          if (!manuallySelected) {
            detectedModule = detectModule(textCtrl.text);
            selectedModule = detectedModule;
          }
          final isFinance = selectedModule.toLowerCase() == 'finanças';
          final isActivity = selectedModule.toLowerCase() == 'atividade física';
          final isFood = selectedModule.toLowerCase() == 'alimentação';
          final isTasks = selectedModule.toLowerCase() == 'tarefas';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(4)),
                  ),
                  Text('Adicionar rapidamente', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  // 1) Texto (mantém)
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Ex: Estudar 30 min amanhã às 18:00', labelText: 'Texto'),
                    onChanged: (val) {
                      setModalState(() {
                        detectedModule = detectModule(val);
                        if (!manuallySelected) selectedModule = detectedModule;

                        if (!descriptionManuallyEdited) {
                          if (val.trim().isEmpty) {
                            descriptionCtrl.text = '';
                          } else {
                            final extracted = _extractDescriptionFromText(val);
                            descriptionCtrl.text = extracted ?? val.trim();
                          }
                        }

                        final parsed = _parseFinanceFromText(val);
                        final double? amt = parsed['amount'] as double?;
                        final String? pm = parsed['paymentMethod'] as String?;
                        final bool? inc = parsed['isIncome'] as bool?;
                        if (amt != null && (financeAmountCtrl.text.isEmpty || financeAmountAutoFilled)) {
                          financeAmountCtrl.text = amt.toStringAsFixed(2);
                          financeAmountAutoFilled = true;
                        }
                        if (pm != null && !financeMethodManuallyEdited) {
                          financePaymentMethod = (inc == true)
                              ? (incomeMethods.contains(pm) ? pm : incomeMethods.first)
                              : (paymentMethods.contains(pm) ? pm : paymentMethods.first);
                        }
                        if (inc != null) financeIsIncome = inc;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2) Módulo (mantém)
                  Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _moduleIconCircle(selectedModule, size: 28, iconSize: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  selectedModule,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        padding: const EdgeInsets.all(6),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Usar sugestão',
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        onPressed: () => setModalState(() {
                          manuallySelected = false;
                          selectedModule = detectedModule;
                        }),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: modules().contains(selectedModule) ? selectedModule : modules().first,
                          items: modules().map((m) => DropdownMenuItem(
                            value: m,
                            child: Row(children: [
                              _moduleIconCircle(m, size: 28, iconSize: 14),
                              const SizedBox(width: 8),
                              Flexible(child: Text(m, overflow: TextOverflow.ellipsis)),
                            ]),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() {
                              selectedModule = v;
                              manuallySelected = true;
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Trocar módulo', isDense: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3) Descrição (apenas UM campo de descrição)
                  TextField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    onChanged: (_) => descriptionManuallyEdited = true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Abaixo: campos organizados conforme o módulo,
                  // mas respeitando a ordem geral pedida quando aplicável:
                  // Prioridade -> Recorrência -> Tempo estimado -> Lembrete -> Data/Hora -> Botões

                  // ---------- TAREFAS ----------
                  if (isTasks) ...[
                    Builder(builder: (_) {
                      // Título: prefer textCtrl (rápido) ou descrição como fallback
                      final titleCtrl = TextEditingController(
                        text: textCtrl.text.trim().isNotEmpty ? textCtrl.text.trim() : descriptionCtrl.text.trim(),
                      );

                      String priority = 'Média';
                      String recurrence = 'Nenhuma';
                      final estCtrl = TextEditingController();
                      final tagsCtrl = TextEditingController();
                      int? reminderMinutes;
                      DateTime? dueDate;
                      TimeOfDay? dueTime;

                      final recurrenceOptions = ['Nenhuma', 'Diária', 'Semanal', 'Mensal'];
                      final reminderOptions = <int>[5, 10, 15, 30, 60, 1440];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          // Prioridade
                          DropdownButtonFormField<String>(
                            value: priority,
                            decoration: const InputDecoration(labelText: 'Prioridade'),
                            items: const [
                              DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                              DropdownMenuItem(value: 'Média', child: Text('Média')),
                              DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                            ],
                            onChanged: (v) => setModalState(() => priority = v ?? 'Média'),
                          ),
                          const SizedBox(height: 12),

                          // Recorrência
                          DropdownButtonFormField<String>(
                            value: recurrence,
                            decoration: const InputDecoration(labelText: 'Recorrência'),
                            items: recurrenceOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setModalState(() => recurrence = v ?? 'Nenhuma'),
                          ),
                          const SizedBox(height: 12),

                          // Tempo estimado
                          TextField(
                            controller: estCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(labelText: 'Tempo estimado (minutos, opcional)'),
                          ),
                          const SizedBox(height: 12),

                          // Lembrete
                          DropdownButtonFormField<int?>(
                            value: reminderMinutes,
                            decoration: const InputDecoration(labelText: 'Lembrete (minutos antes, opcional)'),
                            items: [ const DropdownMenuItem<int?>(value: null, child: Text('Sem lembrete')) ] +
                                reminderOptions.map((m) => DropdownMenuItem<int?>(value: m, child: Text(m == 1440 ? '1 dia antes' : '$m min antes'))).toList(),
                            onChanged: (v) => setModalState(() => reminderMinutes = v),
                          ),
                          const SizedBox(height: 12),

                          // Data e horário
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(dueDate == null ? 'Escolher data' : DateFormat('dd/MM/yyyy').format(dueDate!)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (picked != null) setModalState(() => dueDate = picked);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(dueTime == null ? 'Escolher hora' : '${dueTime!.hour.toString().padLeft(2, '0')}:${dueTime!.minute.toString().padLeft(2, '0')}'),
                                  onPressed: () async {
                                    final picked = await showTimePicker(context: context, initialTime: dueTime ?? TimeOfDay.now());
                                    if (picked != null) setModalState(() => dueTime = picked);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Botões Salvar/Cancelar
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                              const SizedBox(width: 12),
                              Expanded(child: ElevatedButton(
                                onPressed: () {
                                  final title = titleCtrl.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório')));
                                    return;
                                  }
                                  DateTime? due;
                                  if (dueDate != null) {
                                    if (dueTime != null) {
                                      due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day, dueTime!.hour, dueTime!.minute);
                                    } else {
                                      due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 23, 59);
                                    }
                                  }
                                  final est = int.tryParse(estCtrl.text.trim());
                                  final tags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

                                  final key = DateTime.now().millisecondsSinceEpoch.toString();
                                  box.put(key, {
                                    'title': title,
                                    'description': descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
                                    'module': 'Tarefas',
                                    'createdAt': DateTime.now().toIso8601String(),
                                    'due': due?.toIso8601String(),
                                    'priority': priority,
                                    'recurrence': recurrence,
                                    'estimatedMinutes': est,
                                    'tags': tags,
                                    'reminderMinutesBefore': reminderMinutes,
                                    'isDone': false,
                                  });
                                  Navigator.of(context).pop();
                                  setState(() {});
                                },
                                child: const Text('Salvar'),
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // ---------- FINANÇAS ----------
                  if (isFinance) ...[
                    DropdownButtonFormField<String>(
                      value: financeIsIncome ? 'Receita' : 'Despesa',
                      items: const [
                        DropdownMenuItem(value: 'Despesa', child: Text('Despesa')),
                        DropdownMenuItem(value: 'Receita', child: Text('Receita')),
                      ],
                      onChanged: (v) => setModalState(() {
                        financeIsIncome = (v == 'Receita');
                        if (financeIsIncome) financePaymentMethod = incomeMethods.first;
                        else financePaymentMethod = paymentMethods.first;
                        financeMethodManuallyEdited = false;
                      }),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 8),

                    // Valor
                    TextField(
                      controller: financeAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor (Ex: 45.00)'),
                      onChanged: (_) => financeAmountAutoFilled = false,
                    ),
                    const SizedBox(height: 8),

                    // Categoria (apenas para despesa)
                    if (!financeIsIncome) ...[
                      DropdownButtonFormField<String>(
                        value: financeCategory,
                        items: financeCategories().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setModalState(() => financeCategory = v ?? '(Sem categoria)'),
                        decoration: const InputDecoration(labelText: 'Categoria'),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Método de pagamento
                    DropdownButtonFormField<String>(
                      value: financePaymentMethod,
                      items: (financeIsIncome ? incomeMethods : paymentMethods).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setModalState(() {
                        financePaymentMethod = v ?? financePaymentMethod;
                        financeMethodManuallyEdited = true;
                        if (!financeIsIncome && financePaymentMethod != 'Crédito') financeInstallmentsCtrl.text = '1';
                      }),
                      decoration: const InputDecoration(labelText: 'Método de pagamento'),
                    ),
                    const SizedBox(height: 8),

                    // Cartão / Banco (quando aplicável)
                    if (financePaymentMethod != 'Dinheiro/Pix') ...[
                      Builder(builder: (_) {
                        final cardOpts = _activeCardNames();
                        if (!cardOpts.contains(selectedFinanceCard)) {
                          selectedFinanceCard = cardOpts.first;
                        }
                        return DropdownButtonFormField<String>(
                          value: selectedFinanceCard,
                          items: cardOpts.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                          onChanged: (v) => setModalState(() => selectedFinanceCard = v),
                          decoration: const InputDecoration(labelText: 'Cartão / Banco'),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // Número de parcelas somente se Crédito
                    if (!financeIsIncome && financePaymentMethod == 'Crédito') ...[
                      TextField(
                        controller: financeInstallmentsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Número de parcelas'),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Data e Hora (últimos campos antes dos botões)
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: financeDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setModalState(() => financeDate = DateTime(picked.year, picked.month, picked.day, financeTime.hour, financeTime.minute));
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(formatDate(financeDate)),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: financeTime, builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
                          if (picked != null) setModalState(() => financeTime = picked);
                        },
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${financeTime.hour.toString().padLeft(2, '0')}:${financeTime.minute.toString().padLeft(2, '0')}'),
                      )),
                    ]),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () {
                          final amount = double.tryParse(financeAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          final installments = int.tryParse(financeInstallmentsCtrl.text.trim()) ?? 1;
                          final count = installments < 1 ? 1 : installments;
                          final categoryValue = financeIsIncome ? 'Receita' : (financeCategory == '(Sem categoria)' ? '' : financeCategory);
                          final ts = DateTime(financeDate.year, financeDate.month, financeDate.day, financeTime.hour, financeTime.minute);

                          if (count <= 1) {
                            box.add({
                              'title': descriptionCtrl.text.trim().isEmpty ? (financeIsIncome ? 'Receita' : 'Despesa') : descriptionCtrl.text.trim(),
                              'module': 'Finanças',
                              'timestamp': ts.toIso8601String(),
                              'isDone': false,
                              'amount': amount,
                              'category': categoryValue,
                              'paymentMethod': financePaymentMethod,
                              'isIncome': financeIsIncome,
                              'cardName': (selectedFinanceCard == '(Nenhum)') ? null : selectedFinanceCard,
                            });
                          } else {
                            final groupId = DateTime.now().millisecondsSinceEpoch.toString();
                            for (int i = 0; i < count; i++) {
                              final due = DateTime(ts.year, ts.month + i, ts.day, ts.hour, ts.minute);
                              box.add({
                                'title': '${descriptionCtrl.text.trim().isEmpty ? (financeIsIncome ? 'Receita' : 'Despesa') : descriptionCtrl.text.trim()} (${i + 1}/$count)',
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
                                'cardName': (selectedFinanceCard == '(Nenhum)') ? null : selectedFinanceCard,
                              });
                            }
                          }
                          Navigator.of(context).pop();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Salvar'),
                      )),
                    ]),
                    const SizedBox(height: 12),
                  ] else if (isActivity) ...[
                    // ATIVIDADE: reorganizado para que data/hora venham perto do final
                    DropdownButtonFormField<String?>(
                      value: actSelectedKey,
                      items: [
                        if (activities.isEmpty) const DropdownMenuItem(value: null, child: Text('Nenhuma atividade definida')),
                        ...activities.map((a) => DropdownMenuItem(value: a['_key'] as String, child: Text(a['name']))),
                      ],
                      onChanged: (v) => setModalState(() {
                        actSelectedKey = v;
                        if (v != null) {
                          final a = activitiesBox.get(v) as Map?;
                          if (a != null) {
                            actSelectedName = a['name'] ?? actSelectedName;
                            actSelectedUnit = a['unit'] ?? actSelectedUnit;
                          }
                        } else {
                          actSelectedName = '';
                          actSelectedUnit = 'min';
                        }
                        // Ao trocar atividade, resetar seleção de treino
                        selectedWorkoutPlanKey = null;
                        selectedWorkoutPlanName = null;
                      }),
                      decoration: const InputDecoration(labelText: 'Atividade'),
                    ),
                    const SizedBox(height: 8),

                    // Recupera planos de treino locais (para musculação)
                    Builder(builder: (_) {
                      final plans = <Map<String, dynamic>>[];
                      for (var k in workoutPlansBox.keys) {
                        final raw = workoutPlansBox.get(k);
                        if (raw is Map) {
                          final m = Map<String, dynamic>.from(raw);
                          m['_key'] = k;
                          plans.add(m);
                        }
                      }
                      plans.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                      final isMusc = actSelectedName.toLowerCase().contains('muscula');

                      // Duração ou distância
                      Widget measureField;
                      if (actSelectedUnit == 'min') {
                        measureField = TextField(
                          controller: actDurationCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Duração (minutos)'),
                        );
                      } else {
                        measureField = TextField(
                          controller: actDistanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Distância (km)'),
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          measureField,
                          const SizedBox(height: 8),

                          // Se for musculação, mostrar seção Treino (Gerenciar treinos + dropdown de planos)
                          if (isMusc) ...[
                            const SizedBox(height: 6),
                            const Divider(),
                            Row(children: [
                              const Icon(Icons.sports_gymnastics, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Treino', style: TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const WorkoutPlanScreen()));
                                  // Recarrega planos após retorno
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text('Gerenciar treinos'),
                              ),
                            ]),
                            if (plans.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Nenhum treino cadastrado.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ),
                                ]),
                              )
                            else
                              DropdownButtonFormField<String?>(
                                value: selectedWorkoutPlanKey,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Sem treino específico')),
                                  ...plans.map((p) => DropdownMenuItem(value: p['_key'] as String, child: Text(p['name'] as String))),
                                ],
                                onChanged: (v) => setModalState(() {
                                  selectedWorkoutPlanKey = v;
                                  selectedWorkoutPlanName = v != null ? plans.firstWhere((p) => p['_key'] == v)['name'] as String? : null;
                                }),
                                decoration: const InputDecoration(labelText: 'Selecionar treino'),
                              ),
                            const Divider(),
                            const SizedBox(height: 8),
                          ] else ...[
                            // Campos comuns para atividades que não são musculação
                            TextField(
                              controller: actCaloriesCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Calorias (opcional)'),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: actIntensity,
                              items: const [
                                DropdownMenuItem(value: 'Leve', child: Text('Leve')),
                                DropdownMenuItem(value: 'Moderado', child: Text('Moderado')),
                                DropdownMenuItem(value: 'Intenso', child: Text('Intenso')),
                              ],
                              onChanged: (v) => setModalState(() => actIntensity = v ?? 'Moderado'),
                              decoration: const InputDecoration(labelText: 'Intensidade'),
                            ),
                            const SizedBox(height: 8),
                            TextField(controller: actNotesCtrl, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
                            const SizedBox(height: 8),
                          ],

                          // Data + Hora (adicionado hora)
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(context: context, initialDate: actDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setModalState(() => actDate = DateTime(picked.year, picked.month, picked.day, actTime.hour, actTime.minute));
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text('Data: ${formatDate(actDate)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(context: context, initialTime: actTime, builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
                                  if (picked != null) setModalState(() {
                                    actTime = picked;
                                    actDate = DateTime(actDate.year, actDate.month, actDate.day, picked.hour, picked.minute);
                                  });
                                },
                                icon: const Icon(Icons.access_time),
                                label: Text('${actTime.hour.toString().padLeft(2, '0')}:${actTime.minute.toString().padLeft(2, '0')}'),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),

                          // Marcar como realizado (adicionado)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Marcar como realizado'),
                            subtitle: Text(actIsDone ? 'Sessão concluída ✓' : 'Ainda não realizada'),
                            value: actIsDone,
                            secondary: Icon(actIsDone ? Icons.check_circle : Icons.radio_button_unchecked, color: actIsDone ? Colors.green : Colors.grey),
                            onChanged: (v) => setModalState(() => actIsDone = v),
                          ),
                          const SizedBox(height: 8),

                          // Botões Salvar/Cancelar
                          Row(children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                            const SizedBox(width: 12),
                            Expanded(child: ElevatedButton(
                              onPressed: () {
                                final name = actSelectedName.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma atividade')));
                                  return;
                                }
                                final duration = double.tryParse(actDurationCtrl.text.replaceAll(',', '.')) ?? 0.0;
                                final distance = double.tryParse(actDistanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
                                final calories = double.tryParse(actCaloriesCtrl.text.replaceAll(',', '.')) ?? 0.0;
                                final logKey = DateTime.now().millisecondsSinceEpoch.toString();

                                // combina data + hora escolhidos
                                final finalDateTime = DateTime(actDate.year, actDate.month, actDate.day, actTime.hour, actTime.minute);

                                // salva no logsBox
                                logsBox.put(logKey, {
                                  'activityKey': actSelectedKey,
                                  'activityName': name,
                                  'unit': actSelectedUnit,
                                  'durationMinutes': actSelectedUnit == 'min' ? duration : null,
                                  'distanceKm': actSelectedUnit == 'km' ? distance : null,
                                  'calories': calories > 0 ? calories : null,
                                  'intensity': actIntensity,
                                  'notes': actNotesCtrl.text.trim(),
                                  'timestamp': finalDateTime.toIso8601String(),
                                  'createdAt': DateTime.now().toIso8601String(),
                                  'workoutPlanKey': selectedWorkoutPlanKey,
                                  'workoutPlanName': selectedWorkoutPlanName,
                                  'isDone': actIsDone,
                                });

                                String sub = '';
                                if (actSelectedUnit == 'min' && duration > 0) sub = '${duration.toStringAsFixed(0)} min • $actIntensity';
                                if (actSelectedUnit == 'km' && distance > 0) sub = '${distance.toStringAsFixed(2)} km • $actIntensity';
                                if (calories > 0) sub += ' • ${calories.toStringAsFixed(0)} kcal';
                                // para musculação, prioriza nome do treino como subtítulo
                                if (actSelectedName.toLowerCase().contains('muscula')) {
                                  if (selectedWorkoutPlanName != null && selectedWorkoutPlanName!.isNotEmpty) {
                                    sub = selectedWorkoutPlanName!;
                                    if (duration > 0) sub += ' — ${duration.toStringAsFixed(0)} min';
                                    if (calories > 0) sub += ' • ${calories.toStringAsFixed(0)} kcal';
                                  } else {
                                    if (duration > 0) sub = '${duration.toStringAsFixed(0)} min';
                                    if (calories > 0) sub += ' • ${calories.toStringAsFixed(0)} kcal';
                                  }
                                }

                                box.put('activity_$logKey', {
                                  'title': '$name${sub.isNotEmpty ? ' — $sub' : ''}',
                                  'module': 'Atividade Física',
                                  'timestamp': finalDateTime.toIso8601String(),
                                  'isDone': actIsDone,
                                  'activityLogKey': logKey,
                                  'activityName': name,
                                  'unit': actSelectedUnit,
                                  'durationMinutes': actSelectedUnit == 'min' ? duration : null,
                                  'distanceKm': actSelectedUnit == 'km' ? distance : null,
                                  'calories': calories > 0 ? calories : null,
                                  'intensity': actIntensity,
                                  'notes': actNotesCtrl.text.trim(),
                                  'workoutPlanKey': selectedWorkoutPlanKey,
                                  'workoutPlanName': selectedWorkoutPlanName,
                                });
                                Navigator.of(context).pop();
                                if (mounted) setState(() {});
                              },
                              child: const Text('Salvar'),
                            )),
                          ]),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                  ] else if (isFood) ...[
                    // ALIMENTAÇÃO
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: foodSelectedTypeKey,
                          isExpanded: true,
                          items: [
                            if (foodTypes.isEmpty) const DropdownMenuItem(value: null, child: Text('Nenhum tipo cadastrado')),
                            ...foodTypes.map((t) => DropdownMenuItem(value: t['_key'] as String, child: Text(t['name'] as String))),
                          ],
                          onChanged: (v) => setModalState(() {
                            foodSelectedTypeKey = v;
                            if (v != null) {
                              final match = foodTypes.firstWhere((t) => t['_key'] == v);
                              foodSelectedTypeName = match['name'] as String;
                            }
                          }),
                          decoration: const InputDecoration(labelText: 'Tipo de refeição *', isDense: true),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: foodDescCtrl,
                      decoration: const InputDecoration(hintText: 'Ex: Arroz, feijão e salada', labelText: 'Detalhes (opcional)'),
                    ),
                    const SizedBox(height: 12),

                    // Data e hora
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: foodDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setModalState(() => foodDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('${foodDate.day.toString().padLeft(2, '0')}/${foodDate.month.toString().padLeft(2, '0')}/${foodDate.year}'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: foodTime, builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
                          if (picked != null) setModalState(() => foodTime = picked);
                        },
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${foodTime.hour.toString().padLeft(2, '0')}:${foodTime.minute.toString().padLeft(2, '0')}'),
                      )),
                    ]),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Marcar como concluído'),
                      subtitle: Text(foodIsDone ? 'Refeição realizada ✓' : 'Ainda não realizada'),
                      value: foodIsDone,
                      secondary: Icon(foodIsDone ? Icons.check_circle : Icons.radio_button_unchecked, color: foodIsDone ? Colors.green : Colors.grey),
                      onChanged: (v) => setModalState(() => foodIsDone = v),
                    ),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () {
                          if (foodSelectedTypeKey == null || foodSelectedTypeName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um tipo de refeição')));
                            return;
                          }
                          final finalDateTime = DateTime(foodDate.year, foodDate.month, foodDate.day, foodTime.hour, foodTime.minute);
                          box.put(DateTime.now().millisecondsSinceEpoch.toString(), {
                            'title': foodSelectedTypeName,
                            'module': 'Alimentação',
                            'timestamp': finalDateTime.toIso8601String(),
                            'isDone': false,
                            'mealType': foodSelectedTypeName,
                            'mealTypeKey': foodSelectedTypeKey,
                            'description': foodDescCtrl.text.trim().isNotEmpty ? foodDescCtrl.text.trim() : (descriptionCtrl.text.trim().isNotEmpty ? descriptionCtrl.text.trim() : null),
                          });
                          Navigator.of(context).pop();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Salvar'),
                      )),
                    ]),
                    const SizedBox(height: 12),
                  ] else if (!isTasks && !isFinance && !isActivity && !isFood) ...[
                    // GENERIC / OUTROS: descrição já acima. Agora encapsulado em Builder para declarar variáveis locais
                    Builder(builder: (_) {
                      String recurrence = 'Nenhuma';
                      final recurrenceOptions = ['Nenhuma', 'Diária', 'Semanal', 'Mensal'];
                      final estCtrl = TextEditingController();
                      int? reminderMinutes;
                      DateTime finalDate = DateTime.now();
                      TimeOfDay finalTime = TimeOfDay.now();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: recurrence,
                            decoration: const InputDecoration(labelText: 'Recorrência'),
                            items: recurrenceOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setModalState(() => recurrence = v ?? 'Nenhuma'),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: estCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(labelText: 'Tempo estimado (minutos, opcional)'),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<int?>(
                            value: reminderMinutes,
                            decoration: const InputDecoration(labelText: 'Lembrete (minutos antes, opcional)'),
                            items: [ const DropdownMenuItem<int?>(value: null, child: Text('Sem lembrete')) ] +
                                <int>[5, 10, 15, 30, 60, 1440].map((m) => DropdownMenuItem<int?>(value: m, child: Text(m == 1440 ? '1 dia antes' : '$m min antes'))).toList(),
                            onChanged: (v) => setModalState(() => reminderMinutes = v),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(DateFormat('dd/MM/yyyy').format(finalDate)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(context: context, initialDate: finalDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (picked != null) setModalState(() => finalDate = picked);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text('${finalTime.hour.toString().padLeft(2, '0')}:${finalTime.minute.toString().padLeft(2, '0')}'),
                                  onPressed: () async {
                                    final picked = await showTimePicker(context: context, initialTime: finalTime);
                                    if (picked != null) setModalState(() => finalTime = picked);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                              const SizedBox(width: 12),
                              Expanded(child: ElevatedButton(
                                onPressed: () {
                                  final text = descriptionCtrl.text.trim().isNotEmpty ? descriptionCtrl.text.trim() : textCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  final dt = DateTime(finalDate.year, finalDate.month, finalDate.day, finalTime.hour, finalTime.minute);
                                  box.put(DateTime.now().millisecondsSinceEpoch.toString(), {
                                    'title': text,
                                    'module': selectedModule.isEmpty ? '(Sem módulo)' : selectedModule,
                                    'timestamp': dt.toIso8601String(),
                                    'isDone': false,
                                    'recurrence': recurrence,
                                    'estimatedMinutes': int.tryParse(estCtrl.text.trim()),
                                    'reminderMinutesBefore': reminderMinutes,
                                  });
                                  Navigator.of(context).pop();
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Salvar'),
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditItem(Map<String, dynamic> item, dynamic key) {
    final module = (item['module'] as String? ?? '').toLowerCase();
    final mealTypesBox = Hive.box('meal_types');
    final activitiesBox = Hive.box('activities');

    List<Map<String, dynamic>> availableMealTypes() {
      final out = <Map<String, dynamic>>[];
      for (var k in mealTypesBox.keys) {
        final raw = mealTypesBox.get(k);
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          m['_key'] = k;
          out.add(m);
        }
      }
      out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return out;
    }

    String formatDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    final tsRaw = item['timestamp'];
    DateTime baseTs = ((tsRaw is String ? DateTime.tryParse(tsRaw) : null) ?? DateTime.now()).toLocal();

    if (module == 'alimentação') {
      final types = availableMealTypes();
      String? selTypeKey = item['mealTypeKey'] as String?;
      String selTypeName = item['mealType'] as String? ?? (types.isNotEmpty ? types.first['name'] as String : '');
      if (selTypeKey == null && selTypeName.isNotEmpty) {
        try { selTypeKey = types.firstWhere((t) => t['name'] == selTypeName)['_key'] as String?; } catch (_) {}
      }
      if (selTypeKey == null && types.isNotEmpty) { selTypeKey = types.first['_key'] as String; selTypeName = types.first['name'] as String; }
      final descCtrl = TextEditingController(text: item['description'] as String? ?? '');
      DateTime selDate = DateTime(baseTs.year, baseTs.month, baseTs.day);
      TimeOfDay selTime = TimeOfDay(hour: baseTs.hour, minute: baseTs.minute);
      bool isDone = item['isDone'] as bool? ?? false;

      showModalBottomSheet(
        context: context, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(4))),
            Text('Editar Alimentação', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: selTypeKey, isExpanded: true,
              items: [ if (types.isEmpty) const DropdownMenuItem(value: null, child: Text('Nenhum tipo cadastrado')),
                ...types.map((t) => DropdownMenuItem(value: t['_key'] as String, child: Text(t['name'] as String))) ],
              onChanged: (v) => setM(() { selTypeKey = v; if (v != null) { final mt = types.firstWhere((t) => t['_key'] == v); selTypeName = mt['name'] as String; } }),
              decoration: const InputDecoration(labelText: 'Tipo de refeição *', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Ex: Arroz, feijão e salada', labelText: 'Descrição (opcional)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async { final p = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (p != null) setM(() => selDate = p); },
                icon: const Icon(Icons.calendar_today, size: 16), label: Text(formatDate(selDate)))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async { final p = await showTimePicker(context: ctx, initialTime: selTime, builder: (c, ch) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: ch!)); if (p != null) setM(() => selTime = p); },
                icon: const Icon(Icons.access_time, size: 16), label: Text('${selTime.hour.toString().padLeft(2, '0')}:${selTime.minute.toString().padLeft(2, '0')}'))),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar como concluído'),
              subtitle: Text(isDone ? 'Refeição realizada ✓' : 'Ainda não realizada'),
              value: isDone,
              secondary: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
              onChanged: (v) => setM(() => isDone = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  if (selTypeKey == null || selTypeName.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Selecione um tipo de refeição'))); return; }
                  final dt = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
                  box.put(key, { 'title': selTypeName, 'module': 'Alimentação', 'timestamp': dt.toIso8601String(), 'isDone': isDone, 'mealType': selTypeName, 'mealTypeKey': selTypeKey, 'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null });
                  Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Salvar'),
              )),
            ]),
            const SizedBox(height: 18),
          ])),
        )),
      );
      return;
    }

    if (module == 'finanças') {
      final categoriesBox = Hive.box('alfred_finance_categories');

      List<String> financeCategories() {
        final set = <String>{'(Sem categoria)'};
        for (var v in categoriesBox.values) { if (v is String && v.trim().isNotEmpty) set.add(v.trim()); }
        return set.toList()..sort();
      }
      bool isIncome = item['isIncome'] as bool? ?? false;
      final titleCtrl = TextEditingController(text: item['title'] as String? ?? '');
      final amountCtrl = TextEditingController(text: (item['amount'] as double? ?? 0.0).toStringAsFixed(2));
      String category = (item['category'] as String?)?.isNotEmpty == true ? item['category'] as String : '(Sem categoria)';
      String payMethod = item['paymentMethod'] as String? ?? 'Dinheiro/Pix';
      String? selectedFinanceCard = item['cardName'] as String? ?? '(Nenhum)';
      DateTime selDate = baseTs;
      TimeOfDay selTime = TimeOfDay(hour: baseTs.hour, minute: baseTs.minute);
      final paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];
      final incomeMethods = ['Transferência', 'PIX', 'Dinheiro'];

      showModalBottomSheet(
        context: context, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(4))),
            Text('Editar Finanças', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: isIncome ? 'Receita' : 'Despesa',
              items: const [ DropdownMenuItem(value: 'Despesa', child: Text('Despesa')), DropdownMenuItem(value: 'Receita', child: Text('Receita')) ],
              onChanged: (v) => setM(() { isIncome = (v == 'Receita'); payMethod = isIncome ? incomeMethods.first : paymentMethods.first; }),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            const SizedBox(height: 8),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 8),
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
            const SizedBox(height: 8),
            if (!isIncome) ...[
              DropdownButtonFormField<String>(
                value: financeCategories().contains(category) ? category : '(Sem categoria)',
                items: financeCategories().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setM(() => category = v ?? '(Sem categoria)'),
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              value: (isIncome ? incomeMethods : paymentMethods).contains(payMethod) ? payMethod : (isIncome ? incomeMethods.first : paymentMethods.first),
              items: (isIncome ? incomeMethods : paymentMethods).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setM(() => payMethod = v ?? payMethod),
              decoration: const InputDecoration(labelText: 'Método de pagamento'),
            ),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final cardOpts = _activeCardNames();
              String? currentCard = selectedFinanceCard;
              if (!cardOpts.contains(currentCard)) currentCard = cardOpts.first;
              return DropdownButtonFormField<String>(
                value: currentCard,
                items: cardOpts.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => setM(() => selectedFinanceCard = v),
                decoration: const InputDecoration(labelText: 'Cartão / Banco'),
              );
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async { final p = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (p != null) setM(() => selDate = DateTime(p.year, p.month, p.day, selTime.hour, selTime.minute)); },
                icon: const Icon(Icons.calendar_today, size: 16), label: Text(formatDate(selDate)))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async { final p = await showTimePicker(context: ctx, initialTime: selTime, builder: (c, ch) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: ch!)); if (p != null) setM(() => selTime = p); },
                icon: const Icon(Icons.access_time, size: 16), label: Text('${selTime.hour.toString().padLeft(2, '0')}:${selTime.minute.toString().padLeft(2, '0')}'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  final catVal = isIncome ? 'Receita' : (category == '(Sem categoria)' ? '' : category);
                  final finalTs = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
                  final existingData = Map<String, dynamic>.from(box.get(key) as Map);
                  existingData['title'] = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : existingData['title'];
                  existingData['amount'] = amount;
                  existingData['category'] = catVal;
                  existingData['paymentMethod'] = payMethod;
                  existingData['isIncome'] = isIncome;
                  existingData['timestamp'] = finalTs.toIso8601String();
                  existingData['cardName'] = (selectedFinanceCard == '(Nenhum)') ? null : selectedFinanceCard;
                  box.put(key, existingData);
                  Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Salvar'),
              )),
            ]),
            const SizedBox(height: 18),
          ])),
        )),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: item['title'] as String? ?? '');
    DateTime selDate = baseTs;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(4))),
          Text('Editar registro', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async { final p = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (p != null) setM(() => selDate = DateTime(p.year, p.month, p.day, selDate.hour, selDate.minute)); },
            icon: const Icon(Icons.calendar_today), label: Text('Data: ${formatDate(selDate)}'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final existingData = Map<String, dynamic>.from(box.get(key) as Map);
                existingData['title'] = titleCtrl.text.trim();
                existingData['timestamp'] = selDate.toIso8601String();
                box.put(key, existingData);
                Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: const Text('Salvar'),
            )),
          ]),
          const SizedBox(height: 18),
        ])),
      )),
    );
  }

  void _toggleDone(dynamic key) {
    final raw = box.get(key);
    if (raw == null) return;
    final Map item = Map<String, dynamic>.from(raw as Map);
    final newDone = !(item['isDone'] as bool? ?? false);
    item['isDone'] = newDone;
    box.put(key, item);
    final keyStr = key.toString();
    if (keyStr.startsWith('activity_')) {
      final logKey = keyStr.replaceFirst('activity_', '');
      final logsBox = Hive.box('activity_logs');
      final logRaw = logsBox.get(logKey);
      if (logRaw is Map) {
        final logMap = Map<String, dynamic>.from(logRaw);
        logMap['isDone'] = newDone;
        logsBox.put(logKey, logMap);
      }
    }
  }

  void _deleteItem(dynamic key) {
    box.delete(key);
    final keyStr = key.toString();
    if (keyStr.startsWith('activity_')) {
      Hive.box('activity_logs').delete(keyStr.replaceFirst('activity_', ''));
    }
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro'),
        content: const Text('Deseja excluir este registro permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () { _deleteItem(key); Navigator.of(ctx).pop(); },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _itemsForToday(Box b) {
    final now = _selectedDate;
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final List<Map<String, dynamic>> items = [];
    for (var key in b.keys) {
      try {
        final raw = b.get(key);
        if (raw == null) continue;
        final item = Map<String, dynamic>.from(raw as Map);

        final tCandidate = item['timestamp'] ?? item['due'] ?? item['createdAt'];
        if (tCandidate == null) continue;

        DateTime? ts;
        if (tCandidate is int) ts = DateTime.fromMillisecondsSinceEpoch(tCandidate);
        else if (tCandidate is String) ts = DateTime.tryParse(tCandidate);
        else if (tCandidate is DateTime) ts = tCandidate;
        if (ts == null) continue;
        ts = ts.toLocal();

        if (ts.isBefore(start) || ts.isAfter(end)) continue;

        final copy = Map<String, dynamic>.from(item);
        copy['_key'] = key;
        copy['_ts'] = ts;
        items.add(copy);
      } catch (_) {}
    }
    items.sort((a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM', 'pt_BR').format(_selectedDate);
    final dayTitle = _isToday ? 'Hoje' : DateFormat('d MMM', 'pt_BR').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 40,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
        title: GestureDetector(
          onTap: () => setState(() => _selectedDate = DateTime.now()),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(dayTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(dateLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(1)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              switch (val) {
                case 'backup_copy':
                  final json = await BackupService.exportBackupJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup copiado para a área de transferência')));
                  break;
                case 'backup_restore':
                  await BackupService.restoreFromAsset('assets/backups/dev_backup.json');
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restaurado com sucesso')));
                  break;
                case 'modules':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModulesScreen()));
                  break;
                case 'detect_rules':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetectRulesScreen()));
                  break;
                case 'focus':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FocusScreen(taskTitle: 'Estudar Álgebra — Capítulo 3', demoMode: true),
                  ));
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'modules', child: ListTile(leading: Icon(Icons.view_list), title: Text('Módulos'))),
              const PopupMenuItem(value: 'detect_rules', child: ListTile(leading: Icon(Icons.tune), title: Text('Regras de Detecção'))),
              const PopupMenuItem(value: 'focus', child: ListTile(leading: Icon(Icons.center_focus_strong), title: Text('Modo Foco'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'backup_copy', child: ListTile(leading: Icon(Icons.copy_all), title: Text('Copiar Backup'))),
              const PopupMenuItem(value: 'backup_restore', child: ListTile(leading: Icon(Icons.restore), title: Text('Restaurar Backup'))),
            ],
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
              return Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Nenhum registro para este dia. Toque em + para adicionar.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ));
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

                final priority = item['priority'] as String? ?? 'Média';

                final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
                final smallGrey = const TextStyle(fontSize: 12, color: Colors.grey);

                final isFinanceModule = module == 'Finanças';
                String? amountText;
                if (isFinanceModule) {
                  final isIncome = item['isIncome'] as bool? ?? false;
                  final amount = item['amount'] as double? ?? 0.0;
                  final formatted = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(amount);
                  amountText = '${isIncome ? '▲ ' : '▼ '}$formatted';
                }

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
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      minLeadingWidth: 44,
                      leading: GestureDetector(
                        onTap: () => _toggleDone(key),
                        child: _buildCheckOrIcon(item, isDone),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                          color: isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge!.color,
                        ).merge(titleStyle),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (module == 'Tarefas') Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _priorityColor(priority).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.flag, size: 12, color: _priorityColor(priority)),
                                  const SizedBox(width: 6),
                                  Text(priority, style: const TextStyle(fontSize: 12)),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _colorForModule(module).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(_iconForModule(module), size: 12, color: _colorForModule(module)),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 240),
                                    child: Text(
                                      module,
                                      style: const TextStyle(fontSize: 12),
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ]),
                              ),
                              if (amountText != null)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  child: Text(
                                    amountText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: (item['isIncome'] == true) ? Colors.green : Colors.redAccent,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                            ],
                          ),
                          if (module == 'Atividade Física') Builder(builder: (_) {
                            final actName = (item['activityName'] as String? ?? '').toLowerCase();
                            final workoutName = (item['workoutPlanName'] as String?)?.trim();
                            final notes = (item['notes'] as String?)?.trim();
                            final display = (workoutName != null && workoutName.isNotEmpty)
                                ? workoutName
                                : (actName.contains('muscula') && notes != null && notes.isNotEmpty)
                                    ? notes
                                    : null;
                            if (display != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  const Icon(Icons.fitness_center, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(display, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                ]),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                          const SizedBox(height: 6),
                          Text(timeLabel + _buildMetaSuffix(item), style: smallGrey),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        tooltip: 'Mais',
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (v) {
                          if (v == 'edit') _showEditItem(item, key);
                          else if (v == 'delete') _confirmDelete(key);
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
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

  String _buildMetaSuffix(Map<String, dynamic> item) {
    final module = (item['module'] as String? ?? '').toLowerCase();
    if (module == 'finanças') {
      final card = item['cardName'] as String?;
      final category = item['category'] as String?;
      final parts = <String>[];
      if (card != null && card.isNotEmpty) parts.add(card);
      if (category != null && category.isNotEmpty) parts.add('Categoria: $category');
      if (parts.isEmpty) return '';
      return ' • ' + parts.join(' • ');
    } else if (module == 'atividade física') {
      final intensity = item['intensity'] as String?;
      if (intensity != null && intensity.isNotEmpty) return ' • Intensidade: $intensity';
    }
    return '';
  }

  double _installmentAmount(double total, int count, int index) {
    if (count <= 1) return total;
    final base = double.parse((total / count).toStringAsFixed(2));
    if (index < count - 1) return base;
    return double.parse((total - base * (count - 1)).toStringAsFixed(2));
  }
}