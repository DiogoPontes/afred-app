// lib/screens/food_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'meal_type_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({Key? key}) : super(key: key);

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

enum FoodPeriod { today, week, month, custom }

class _FoodScreenState extends State<FoodScreen> {
  final Box _alfredBox = Hive.box('alfred_box');
  final Box _mealTypesBox = Hive.box('meal_types');

  FoodPeriod _period = FoodPeriod.today;
  DateTimeRange? _customRange;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ensureDefaultMealTypes();
  }

  void _ensureDefaultMealTypes() {
    if (_mealTypesBox.isEmpty) {
      final defaults = [
        'Café da manhã',
        'Lanche da manhã',
        'Almoço',
        'Lanche da tarde',
        'Jantar',
        'Ceia',
      ];
      for (var name in defaults) {
        final key = '${DateTime.now().millisecondsSinceEpoch}-${name.hashCode}';
        _mealTypesBox.put(key, {
          'name': name,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange _rangeForPeriod() {
    final now = DateTime.now();
    switch (_period) {
      case FoodPeriod.today:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case FoodPeriod.week:
        return DateTimeRange(
            start: _startOfDay(now.subtract(const Duration(days: 6))),
            end: _endOfDay(now));
      case FoodPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final next = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(
            start: start,
            end: next.subtract(const Duration(milliseconds: 1)));
      case FoodPeriod.custom:
        return _customRange ??
            DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  List<Map<String, dynamic>> _filteredItems() {
    final range = _rangeForPeriod();
    final out = <Map<String, dynamic>>[];
    for (var k in _alfredBox.keys) {
      try {
        final raw = _alfredBox.get(k);
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        if ((m['module'] as String? ?? '') != 'Alimentação') continue;

        final tsVal = m['timestamp'];
        DateTime? ts;
        if (tsVal is String) ts = DateTime.tryParse(tsVal);
        else if (tsVal is int) ts = DateTime.fromMillisecondsSinceEpoch(tsVal);
        else if (tsVal is DateTime) ts = tsVal;
        if (ts == null) continue;
        ts = ts.toLocal();

        if (ts.isBefore(range.start) || ts.isAfter(range.end)) continue;

        final title = (m['title'] as String? ?? '').toLowerCase();
        final mealType = (m['mealType'] as String? ?? '').toLowerCase();
        final desc = (m['description'] as String? ?? '').toLowerCase();
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          if (!title.contains(q) && !mealType.contains(q) && !desc.contains(q)) continue;
        }

        m['_key'] = k;
        m['_ts'] = ts;
        out.add(m);
      } catch (_) {}
    }
    out.sort((a, b) => (a['_ts'] as DateTime).compareTo(b['_ts'] as DateTime));
    return out;
  }

  List<Map<String, dynamic>> _availableMealTypes() {
    final out = <Map<String, dynamic>>[];
    for (var k in _mealTypesBox.keys) {
      final raw = _mealTypesBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        out.add(m);
      }
    }
    out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  void _toggleDone(dynamic key) {
    final raw = _alfredBox.get(key);
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    m['isDone'] = !(m['isDone'] as bool? ?? false);
    _alfredBox.put(key, m);
    setState(() {});
  }

  void _deleteItem(dynamic key) {
    _alfredBox.delete(key);
    setState(() {});
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir refeição'),
        content: const Text('Deseja remover este registro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _deleteItem(key);
              Navigator.pop(ctx);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
            start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _customRange = DateTimeRange(
            start: _startOfDay(picked.start), end: _endOfDay(picked.end));
        _period = FoodPeriod.custom;
      });
    }
  }

  String _labelForPeriod() {
    if (_period == FoodPeriod.today) return 'Hoje';
    if (_period == FoodPeriod.week) return 'Últimos 7 dias';
    if (_period == FoodPeriod.month) return 'Mês atual';
    if (_period == FoodPeriod.custom && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return '${s.day}/${s.month}/${s.year} — ${e.day}/${e.month}/${e.year}';
    }
    return 'Período';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _formatDayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(d.year, d.month, d.day);
    if (check == today) return 'Hoje';
    if (check == yesterday) return 'Ontem';
    final weekdays = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    final months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return '${weekdays[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}${d.year == now.year ? '' : ' ${d.year}'}';
  }

  Future<void> _showAddOrEdit({Map<String, dynamic>? existing, dynamic key}) async {
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');

    DateTime baseTs = DateTime.tryParse(existing?['timestamp'] as String? ?? '') ?? DateTime.now();
    DateTime selectedDate = DateTime(baseTs.year, baseTs.month, baseTs.day);
    TimeOfDay selectedTime = TimeOfDay(hour: baseTs.hour, minute: baseTs.minute);

    bool isDone = existing?['isDone'] as bool? ?? false;

    final types = _availableMealTypes();
    String? selectedTypeKey = existing?['mealTypeKey'] as String?;
    String selectedTypeName = existing?['mealType'] as String? ??
        (types.isNotEmpty ? types.first['name'] as String : '');

    if (selectedTypeKey == null && selectedTypeName.isNotEmpty) {
      try {
        selectedTypeKey = types.firstWhere(
          (t) => (t['name'] as String?) == selectedTypeName,
        )['_key'] as String?;
      } catch (_) {}
    }
    if (selectedTypeKey == null && types.isNotEmpty) {
      selectedTypeKey = types.first['_key'] as String;
      selectedTypeName = types.first['name'] as String;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return StatefulBuilder(builder: (bctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bctx).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
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
                    existing != null ? 'Editar refeição' : 'Adicionar item',
                    style: Theme.of(bctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // ── Tipo de refeição (obrigatório) ──────────────────────
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: selectedTypeKey,
                        isExpanded: true,
                        items: [
                          if (types.isEmpty)
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Nenhum tipo cadastrado'),
                            ),
                          ...types.map((t) => DropdownMenuItem(
                                value: t['_key'] as String,
                                child: Text(t['name'] as String),
                              )),
                        ],
                        onChanged: (v) => setModal(() {
                          selectedTypeKey = v;
                          if (v != null) {
                            final match = types.firstWhere((t) => t['_key'] == v);
                            selectedTypeName = match['name'] as String;
                          }
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Tipo de refeição *',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          bctx,
                          MaterialPageRoute(builder: (_) => const MealTypeScreen()),
                        );
                        setModal(() {});
                      },
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Gerenciar'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Descrição (opcional) ────────────────────────────────
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Arroz, feijão e salada',
                      labelText: 'Descrição (opcional)',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Data + Hora ─────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: bctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setModal(() => selectedDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: bctx,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  alwaysUse24HourFormat: true,
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setModal(() => selectedTime = picked);
                        },
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Realizado? ────────────────────────────────────────
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marcar como concluído'),
                    subtitle: Text(isDone ? 'Refeição realizada ✓' : 'Ainda não realizada'),
                    value: isDone,
                    secondary: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? Colors.green : Colors.grey,
                    ),
                    onChanged: (v) => setModal(() => isDone = v),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Botões ──────────────────────────────────────────────
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
                          if (selectedTypeKey == null || selectedTypeName.isEmpty) {
                            ScaffoldMessenger.of(bctx).showSnackBar(
                              const SnackBar(content: Text('Selecione um tipo de refeição')),
                            );
                            return;
                          }

                          final description = descCtrl.text.trim();

                          final finalDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          final data = {
                            'title': selectedTypeName,
                            'module': 'Alimentação',
                            'timestamp': finalDateTime.toIso8601String(),
                            'isDone': isDone,
                            'mealType': selectedTypeName,
                            'mealTypeKey': selectedTypeKey,
                            'description': description.isNotEmpty ? description : null,
                          };

                          if (existing != null && key != null) {
                            _alfredBox.put(key, data);
                          } else {
                            _alfredBox.put(
                              DateTime.now().millisecondsSinceEpoch.toString(),
                              data,
                            );
                          }

                          Navigator.pop(bctx);
                          setState(() {});
                        },
                        child: Text(existing != null ? 'Salvar' : 'Registrar'),
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems();
    final doneCount = items.where((i) => i['isDone'] as bool? ?? false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Gerenciar tipos de refeição',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MealTypeScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Filtro de período ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              DropdownButton<FoodPeriod>(
                value: _period,
                items: const [
                  DropdownMenuItem(value: FoodPeriod.today, child: Text('Hoje')),
                  DropdownMenuItem(value: FoodPeriod.week, child: Text('Semana')),
                  DropdownMenuItem(value: FoodPeriod.month, child: Text('Mês')),
                  DropdownMenuItem(value: FoodPeriod.custom, child: Text('Personalizado')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  if (v == FoodPeriod.custom) {
                    await _pickCustomRange();
                  } else {
                    setState(() => _period = v);
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(_labelForPeriod()),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {}),
              ),
            ]),
          ),

          // ── Busca ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar refeição...',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // ── Resumo ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      const Text('Registros', style: TextStyle(fontSize: 12)),
                      Text('${items.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                    Column(children: [
                      const Text('Realizadas', style: TextStyle(fontSize: 12)),
                      Text('$doneCount',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // ── Lista ────────────────────────────────────────────────────────
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _alfredBox.listenable(),
              builder: (context, Box box, _) {
                final l = _filteredItems();
                if (l.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Nenhuma refeição registrada em ${_labelForPeriod()}.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // ── Agrupar por dia ─────────────────────────────────────────
                final grouped = <DateTime, List<Map<String, dynamic>>>{};
                for (var item in l) {
                  final ts = item['_ts'] as DateTime;
                  final day = DateTime(ts.year, ts.month, ts.day);
                  grouped.putIfAbsent(day, () => []);
                  grouped[day]!.add(item);
                }
                // ordena dias decrescente (mais recente primeiro)
                final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length,
                  itemBuilder: (context, dayIndex) {
                    final day = days[dayIndex];
                    final itemsDay = grouped[day]!;
                    // ordena itens do dia por hora crescente
                    itemsDay.sort((a, b) => (a['_ts'] as DateTime).compareTo(b['_ts'] as DateTime));

                    final dayLabel = _formatDayLabel(day);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Cabeçalho do dia ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.pink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dayLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.pink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${itemsDay.length} refeição${itemsDay.length == 1 ? '' : 'ões'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        // ── Itens do dia ──────────────────────────────────
                        ...itemsDay.map((item) {
                          final key = item['_key'];
                          final ts = item['_ts'] as DateTime;
                          final mealType = item['mealType'] as String? ?? '';
                          final description = item['description'] as String? ?? '';
                          final isDone = item['isDone'] as bool? ?? false;

                          return Dismissible(
                            key: Key('$key-${dayIndex}-${itemsDay.indexOf(item)}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.redAccent,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteItem(key),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                leading: GestureDetector(
                                  onTap: () => _toggleDone(key),
                                  child: Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: isDone ? Colors.green : Colors.transparent,
                                      border: Border.all(
                                          color: isDone ? Colors.green : Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: isDone
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : const Icon(Icons.circle_outlined, size: 20),
                                  ),
                                ),
                                title: Text(
                                  mealType,
                                  style: TextStyle(
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    color: isDone ? Colors.grey : null,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (description.isNotEmpty) ...[
                                      Expanded(
                                        child: Text(
                                          description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDone ? Colors.grey[500] : Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('•', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(_formatTime(ts), style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAddOrEdit(existing: item, key: key),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _confirmDelete(key),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
