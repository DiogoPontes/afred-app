// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum ActivityPeriod { today, week, month, custom }

class _ActivityScreenState extends State<ActivityScreen> {
  final Box _activitiesBox = Hive.box('activities');
  final Box _logsBox = Hive.box('activity_logs');
  final Box _alfredBox = Hive.box('alfred_box'); // para sincronizar com a home

  ActivityPeriod _period = ActivityPeriod.today;
  DateTimeRange? _customRange;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ensureDefaultActivities();
  }

  void _ensureDefaultActivities() {
    if (_activitiesBox.isEmpty) {
      final defaults = [
        {'id': 'musculacao', 'name': 'Musculação', 'unit': 'min'},
        {'id': 'natacao', 'name': 'Natação', 'unit': 'min'},
        {'id': 'corrida', 'name': 'Corrida', 'unit': 'km'},
        {'id': 'ciclismo', 'name': 'Ciclismo', 'unit': 'km'},
        {'id': 'yoga', 'name': 'Yoga', 'unit': 'min'},
      ];
      for (var a in defaults) {
        final key = '${DateTime.now().millisecondsSinceEpoch}-${a['id']}';
        _activitiesBox.put(key, a);
      }
    }
  }

  // ── helpers de data ──────────────────────────────────────────────────────────
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange _rangeForPeriod() {
    final now = DateTime.now();
    switch (_period) {
      case ActivityPeriod.today:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case ActivityPeriod.week:
        return DateTimeRange(start: _startOfDay(now.subtract(const Duration(days: 6))), end: _endOfDay(now));
      case ActivityPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final next = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(start: start, end: next.subtract(const Duration(milliseconds: 1)));
      case ActivityPeriod.custom:
        return _customRange ?? DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  // ── listas ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _availableActivities() {
    final out = <Map<String, dynamic>>[];
    for (var k in _activitiesBox.keys) {
      final raw = _activitiesBox.get(k);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        out.add(m);
      }
    }
    out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  List<Map<String, dynamic>> _filteredLogs() {
    final range = _rangeForPeriod();
    final out = <Map<String, dynamic>>[];
    for (var k in _logsBox.keys) {
      try {
        final raw = _logsBox.get(k);
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final tsVal = m['timestamp'];
          DateTime? ts;
          if (tsVal is String) ts = DateTime.tryParse(tsVal);
          else if (tsVal is int) ts = DateTime.fromMillisecondsSinceEpoch(tsVal);
          else if (tsVal is DateTime) ts = tsVal;
          if (ts == null) continue;
          if (ts.isBefore(range.start) || ts.isAfter(range.end)) continue;
          final title = (m['activityName'] as String? ?? '').toLowerCase();
          if (_search.isNotEmpty && !title.contains(_search.toLowerCase())) continue;
          m['_key'] = k;
          m['_ts'] = ts;
          out.add(m);
        }
      } catch (_) {}
    }
    out.sort((a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime));
    return out;
  }

  // ── somas ────────────────────────────────────────────────────────────────────
  double _sumMinutes(List<Map<String, dynamic>> logs) =>
      logs.fold(0, (s, l) => s + ((l['durationMinutes'] is num) ? (l['durationMinutes'] as num).toDouble() : 0.0));

  double _sumCalories(List<Map<String, dynamic>> logs) =>
      logs.fold(0, (s, l) => s + ((l['calories'] is num) ? (l['calories'] as num).toDouble() : 0.0));

  // ── sincronização com alfred_box ─────────────────────────────────────────────
  /// Salva ou atualiza o espelho na alfred_box para aparecer na home.
  void _syncToAlfredBox({
    required String logKey,
    required String activityName,
    required String unit,
    required double? durationMinutes,
    required double? distanceKm,
    required double? calories,
    required String intensity,
    required String notes,
    required DateTime timestamp,
  }) {
    final alfredKey = 'activity_$logKey';
    String subtitle = '';
    if (unit == 'min' && durationMinutes != null) subtitle = '${durationMinutes.toStringAsFixed(0)} min • $intensity';
    if (unit == 'km' && distanceKm != null) subtitle = '${distanceKm.toStringAsFixed(2)} km • $intensity';
    if (calories != null && calories > 0) subtitle += ' • ${calories.toStringAsFixed(0)} kcal';

    final item = {
      'title': '$activityName${subtitle.isNotEmpty ? ' — $subtitle' : ''}',
      'module': 'Atividade Física',
      'timestamp': timestamp.toIso8601String(),
      'isDone': false,
      'activityLogKey': logKey,
      // campos extras para exibição
      'activityName': activityName,
      'unit': unit,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
      'calories': calories,
      'intensity': intensity,
      'notes': notes,
    };
    _alfredBox.put(alfredKey, item);
  }

  /// Remove o espelho da alfred_box quando o log for deletado.
  void _removeFromAlfredBox(String logKey) {
    _alfredBox.delete('activity_$logKey');
  }

  // ── pickers ──────────────────────────────────────────────────────────────────
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
        context: context, firstDate: DateTime(2000), lastDate: DateTime(now.year + 5), initialDateRange: initial);
    if (picked != null) {
      setState(() {
        _customRange = DateTimeRange(start: _startOfDay(picked.start), end: _endOfDay(picked.end));
        _period = ActivityPeriod.custom;
      });
    }
  }

  String _formatDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ── modais ───────────────────────────────────────────────────────────────────
  Future<void> _showManageActivities() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          final activities = _availableActivities();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [Expanded(child: Text('Atividades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))])),
              const SizedBox(height: 8),
              if (activities.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma atividade definida. Toque + para criar.'))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activities.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final a = activities[i];
                      return ListTile(
                        title: Text(a['name'] ?? ''),
                        subtitle: Text('Unidade: ${a['unit'] ?? 'min'}'),
                        leading: const Icon(Icons.fitness_center),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                            await _showAddOrEditActivity(ctx, hiveKey: a['_key']);
                            setModal(() {});
                          }),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () {
                            showDialog(context: ctx, builder: (dctx) => AlertDialog(
                              title: const Text('Confirmar exclusão'),
                              content: Text('Excluir "${a['name']}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () {
                                  _activitiesBox.delete(a['_key']);
                                  Navigator.pop(dctx);
                                  setModal(() {});
                                }, child: const Text('Excluir')),
                              ],
                            ));
                          }),
                        ]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _showAddOrEditActivity(ctx, hiveKey: null);
                      setModal(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar atividade'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          );
        });
      },
    );
  }

  Future<void> _showAddOrEditActivity(BuildContext ctx, {dynamic hiveKey}) async {
    final nameCtrl = TextEditingController();
    String unit = 'min';

    if (hiveKey != null) {
      final existing = Map<String, dynamic>.from(_activitiesBox.get(hiveKey) as Map);
      nameCtrl.text = existing['name'] ?? '';
      unit = existing['unit'] ?? 'min';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bctx) {
        return StatefulBuilder(builder: (bctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(hiveKey == null ? 'Nova atividade' : 'Editar atividade',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome da atividade')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'min', child: Text('Minutos (min)')),
                      DropdownMenuItem(value: 'km', child: Text('Quilômetros (km)')),
                    ],
                    onChanged: (v) => setModal(() => unit = v ?? 'min'),
                    decoration: const InputDecoration(labelText: 'Unidade padrão'),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(bctx), child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um nome')));
                        return;
                      }
                      final id = hiveKey ?? DateTime.now().millisecondsSinceEpoch.toString();
                      _activitiesBox.put(id, {'id': id, 'name': name, 'unit': unit});
                      Navigator.pop(bctx);
                    }, child: const Text('Salvar'))),
                  ]),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _showAddLog({BuildContext? parentCtx, Map<String, dynamic>? existing, dynamic hiveKey}) async {
    final ctx = parentCtx ?? context;
    final activities = _availableActivities();

    final durationCtrl = TextEditingController(
        text: existing?['durationMinutes'] != null ? existing!['durationMinutes'].toString() : '');
    final distanceCtrl = TextEditingController(
        text: existing?['distanceKm'] != null ? existing!['distanceKm'].toString() : '');
    final caloriesCtrl = TextEditingController(
        text: existing?['calories'] != null ? existing!['calories'].toString() : '');
    final notesCtrl = TextEditingController(text: existing?['notes'] as String? ?? '');

    String? selectedActivityKey = existing?['activityKey'] as String? ??
        (activities.isNotEmpty ? activities.first['_key'] as String : null);
    String selectedActivityName = existing?['activityName'] as String? ??
        (activities.isNotEmpty ? activities.first['name'] as String : '');
    String selectedUnit = existing?['unit'] as String? ??
        (activities.isNotEmpty ? activities.first['unit'] as String : 'min');
    DateTime selectedDate =
        DateTime.tryParse(existing?['timestamp'] as String? ?? '') ?? DateTime.now();
    String intensity = existing?['intensity'] as String? ?? 'Moderado';

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (bctx) {
        return StatefulBuilder(builder: (bctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(bctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(existing != null ? 'Editar sessão' : 'Registrar sessão',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Dropdown de atividade
                  DropdownButtonFormField<String?>(
                    value: selectedActivityKey,
                    items: [
                      if (activities.isEmpty)
                        const DropdownMenuItem(value: null, child: Text('Nenhuma atividade definida')),
                      ...activities.map((a) =>
                          DropdownMenuItem(value: a['_key'] as String, child: Text(a['name']))),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Adicionar nova atividade...')),
                    ],
                    onChanged: (v) async {
                      if (v == '__add_new__') {
                        await _showAddOrEditActivity(bctx, hiveKey: null);
                        setModal(() {
                          final updated = _availableActivities();
                          if (updated.isNotEmpty) {
                            selectedActivityKey = updated.first['_key'] as String;
                            selectedActivityName = updated.first['name'] as String;
                            selectedUnit = updated.first['unit'] as String? ?? 'min';
                          }
                        });
                      } else {
                        setModal(() {
                          selectedActivityKey = v;
                          if (v != null) {
                            final a = _activitiesBox.get(v) as Map?;
                            if (a != null) {
                              selectedActivityName = a['name'] ?? selectedActivityName;
                              selectedUnit = a['unit'] ?? selectedUnit;
                            }
                          } else {
                            selectedActivityName = '';
                            selectedUnit = 'min';
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Atividade'),
                  ),
                  const SizedBox(height: 12),

                  // Duração ou distância conforme unidade
                  if (selectedUnit == 'min') ...[
                    TextField(
                        controller: durationCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Duração (minutos)')),
                    const SizedBox(height: 8),
                  ] else ...[
                    TextField(
                        controller: distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Distância (km)')),
                    const SizedBox(height: 8),
                  ],

                  TextField(
                      controller: caloriesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Calorias (opcional)')),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: intensity,
                    items: const [
                      DropdownMenuItem(value: 'Leve', child: Text('Leve')),
                      DropdownMenuItem(value: 'Moderado', child: Text('Moderado')),
                      DropdownMenuItem(value: 'Intenso', child: Text('Intenso')),
                    ],
                    onChanged: (v) => setModal(() => intensity = v ?? 'Moderado'),
                    decoration: const InputDecoration(labelText: 'Intensidade'),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notas (opcional)')),
                  const SizedBox(height: 12),

                  // Seletor de data
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: bctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (picked != null) {
                          setModal(() => selectedDate = DateTime(
                              picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute));
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_formatDateShort(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(bctx), child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () {
                        final name = selectedActivityName.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Selecione ou crie uma atividade')));
                          return;
                        }

                        final duration = double.tryParse(durationCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        final distance = double.tryParse(distanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        final calories = double.tryParse(caloriesCtrl.text.replaceAll(',', '.')) ?? 0.0;

                        final logData = {
                          'activityKey': selectedActivityKey,
                          'activityName': name,
                          'unit': selectedUnit,
                          'durationMinutes': selectedUnit == 'min' ? duration : null,
                          'distanceKm': selectedUnit == 'km' ? distance : null,
                          'calories': calories > 0 ? calories : null,
                          'intensity': intensity,
                          'notes': notesCtrl.text.trim(),
                          'timestamp': selectedDate.toIso8601String(),
                          'createdAt': DateTime.now().toIso8601String(),
                        };

                        String logKey;
                        if (existing != null && hiveKey != null) {
                          _logsBox.put(hiveKey, logData);
                          logKey = hiveKey.toString();
                        } else {
                          final newKey = DateTime.now().millisecondsSinceEpoch.toString();
                          _logsBox.put(newKey, logData);
                          logKey = newKey;
                        }

                        // sincroniza com alfred_box (home)
                        _syncToAlfredBox(
                          logKey: logKey,
                          activityName: name,
                          unit: selectedUnit,
                          durationMinutes: selectedUnit == 'min' ? duration : null,
                          distanceKm: selectedUnit == 'km' ? distance : null,
                          calories: calories > 0 ? calories : null,
                          intensity: intensity,
                          notes: notesCtrl.text.trim(),
                          timestamp: selectedDate,
                        );

                        Navigator.pop(bctx);
                        setState(() {});
                      },
                      child: Text(existing != null ? 'Salvar' : 'Registrar'),
                    )),
                  ]),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  String _labelForPeriod() {
    if (_period == ActivityPeriod.today) return 'Hoje';
    if (_period == ActivityPeriod.week) return 'Últimos 7 dias';
    if (_period == ActivityPeriod.month) return 'Mês atual';
    if (_period == ActivityPeriod.custom && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return '${s.day}/${s.month}/${s.year} — ${e.day}/${e.month}/${e.year}';
    }
    return 'Período';
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs();
    final totalSessions = logs.length;
    final totalMinutes = _sumMinutes(logs);
    final totalCalories = _sumCalories(logs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atividade Física'),
        actions: [
          IconButton(
              icon: const Icon(Icons.fitness_center),
              tooltip: 'Gerenciar atividades',
              onPressed: _showManageActivities),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLog(),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        // Filtro de período
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            DropdownButton<ActivityPeriod>(
              value: _period,
              items: const [
                DropdownMenuItem(value: ActivityPeriod.today, child: Text('Hoje')),
                DropdownMenuItem(value: ActivityPeriod.week, child: Text('Semana')),
                DropdownMenuItem(value: ActivityPeriod.month, child: Text('Mês')),
                DropdownMenuItem(value: ActivityPeriod.custom, child: Text('Personalizado')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                if (v == ActivityPeriod.custom) {
                  await _pickCustomRange();
                } else {
                  setState(() => _period = v);
                }
              },
            ),
            const SizedBox(width: 8),
            Text(_labelForPeriod()),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
          ]),
        ),

        // Busca
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar atividade...'),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showManageActivities),
          ]),
        ),

        // Resumo
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sessões', style: TextStyle(fontSize: 12)),
                  Text('$totalSessions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Minutos', style: TextStyle(fontSize: 12)),
                  Text(totalMinutes.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Calorias', style: TextStyle(fontSize: 12)),
                  Text(totalCalories.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ]),
            ),
          ),
        ),

        // Lista de logs
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _logsBox.listenable(),
            builder: (context, Box box, _) {
              final l = _filteredLogs();
              if (l.isEmpty) {
                return Center(child: Text('Nenhuma sessão registrada em ${_labelForPeriod()}.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: l.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = l[i];
                  final key = item['_key'];
                  final ts = item['_ts'] as DateTime;
                  final title = item['activityName'] as String? ?? '';
                  final unit = item['unit'] as String? ?? 'min';
                  final dur = (item['durationMinutes'] is num) ? (item['durationMinutes'] as num).toDouble() : null;
                  final dist = (item['distanceKm'] is num) ? (item['distanceKm'] as num).toDouble() : null;
                  final cal = (item['calories'] is num) ? (item['calories'] as num).toDouble() : null;
                  final intensity = item['intensity'] as String? ?? '';
                  final notes = item['notes'] as String? ?? '';

                  String subtitle = '';
                  if (unit == 'min' && dur != null) subtitle = '${dur.toStringAsFixed(0)} min • $intensity';
                  if (unit == 'km' && dist != null) subtitle = '${dist.toStringAsFixed(2)} km • $intensity';
                  if (cal != null) subtitle += ' • ${cal.toStringAsFixed(0)} kcal';

                  return Dismissible(
                    key: Key('$key-$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) {
                      if (key != null) {
                        _logsBox.delete(key);
                        _removeFromAlfredBox(key.toString()); // remove da home também
                      }
                      setState(() {});
                    },
                    child: ListTile(
                      title: Text(title),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(subtitle),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(notes, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                        const SizedBox(height: 4),
                        Text(_formatDateShort(ts), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddLog(parentCtx: context, existing: item, hiveKey: key)),
                      onTap: () => _showAddLog(parentCtx: context, existing: item, hiveKey: key),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}