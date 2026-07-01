// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

enum TaskPeriod { today, week, month, year, custom }

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late Box box;

  TaskPeriod _period = TaskPeriod.today;
  DateTimeRange? _customRange;
  String _search = '';

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box');
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange _rangeForPeriod() {
    final now = DateTime.now();
    switch (_period) {
      case TaskPeriod.today:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case TaskPeriod.week:
        return DateTimeRange(
            start: _startOfDay(now.subtract(const Duration(days: 6))),
            end: _endOfDay(now));
      case TaskPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final next = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(
            start: start, end: next.subtract(const Duration(milliseconds: 1)));
      case TaskPeriod.year:
        final start = DateTime(now.year, 1, 1);
        final next = DateTime(now.year + 1, 1, 1);
        return DateTimeRange(
            start: start, end: next.subtract(const Duration(milliseconds: 1)));
      case TaskPeriod.custom:
        return _customRange ??
            DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _customRange =
            DateTimeRange(start: _startOfDay(picked.start), end: _endOfDay(picked.end));
        _period = TaskPeriod.custom;
      });
    }
  }

  String _labelForPeriod() {
    if (_period == TaskPeriod.today) return 'Hoje';
    if (_period == TaskPeriod.week) return 'Últimos 7 dias';
    if (_period == TaskPeriod.month) return 'Mês atual';
    if (_period == TaskPeriod.year) return 'Ano atual';
    if (_period == TaskPeriod.custom && _customRange != null) {
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

  List<Map<String, dynamic>> _filteredItems() {
    final range = _rangeForPeriod();
    final out = <Map<String, dynamic>>[];
    for (var k in box.keys) {
      try {
        final raw = box.get(k);
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);

        if ((m['module'] as String? ?? '').toLowerCase() != 'tarefas') continue;

        // Prefer 'due' for filtering; if absent, try 'createdAt'
        final dueVal = m['due'] ?? m['timestamp'] ?? m['createdAt'];
        DateTime? ts;
        if (dueVal is String) ts = DateTime.tryParse(dueVal);
        else if (dueVal is int) ts = DateTime.fromMillisecondsSinceEpoch(dueVal);
        else if (dueVal is DateTime) ts = dueVal;
        if (ts == null) continue;
        ts = ts.toLocal();

        if (ts.isBefore(range.start) || ts.isAfter(range.end)) continue;

        final title = (m['title'] as String? ?? '').toLowerCase();
        final desc = (m['description'] as String? ?? '').toLowerCase();
        final tagsList = (m['tags'] as List?)?.join(' ').toLowerCase() ?? '';

        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          if (!title.contains(q) && !desc.contains(q) && !tagsList.contains(q)) continue;
        }

        m['_key'] = k;
        m['_due'] = ts;
        out.add(m);
      } catch (_) {}
    }
    out.sort((a, b) {
      final da = a['_due'] as DateTime?;
      final db = b['_due'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return out;
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

  void _toggleDone(dynamic key) {
    final raw = box.get(key);
    if (raw == null) return;
    final item = Map<String, dynamic>.from(raw as Map);
    item['isDone'] = !(item['isDone'] as bool? ?? false);
    box.put(key, item);
    setState(() {});
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: const Text('Deseja excluir esta tarefa permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              box.delete(key);
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddTaskModal() {
    // Modificado para repetir exatamente os campos / comportamento do Quick Add (Tarefas)
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'Média';
    DateTime? dueDate;
    TimeOfDay? dueTime;
    String recurrence = 'Nenhuma';
    final estCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    int? reminderMinutes; // e.g., 5, 10, 15, 30, 60, 1440

    final recurrenceOptions = ['Nenhuma', 'Diária', 'Semanal', 'Mensal'];
    final reminderOptions = <int>[5, 10, 15, 30, 60, 1440];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(4))),
                  Text('Nova tarefa', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),

                  // Título
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 8),

                  // Descrição
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
                  const SizedBox(height: 12),

                  // Prioridade (igual ao Quick Add)
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

                  // Data e horário (linha com dois botões)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(dueDate == null ? 'Escolher data' : DateFormat('dd/MM/yyyy').format(dueDate!)),
                          onPressed: () async {
                            final picked = await showDatePicker(context: ctx, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
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
                            final picked = await showTimePicker(context: ctx, initialTime: dueTime ?? TimeOfDay.now());
                            if (picked != null) setModalState(() => dueTime = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botões Salvar / Cancelar
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar'))),
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
                            'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
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
                          Navigator.of(ctx).pop();
                          setState(() {});
                        },
                        child: const Text('Salvar'),
                      )),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditTask(Map<String, dynamic> task, dynamic key) {
    final titleCtrl = TextEditingController(text: task['title'] as String? ?? '');
    final descCtrl = TextEditingController(text: task['description'] as String? ?? '');
    String priority = task['priority'] as String? ?? 'Média';
    DateTime? dueDate;
    TimeOfDay? dueTime;
    if (task['due'] != null) {
      final parsed = DateTime.tryParse(task['due']);
      if (parsed != null) {
        final local = parsed.toLocal();
        dueDate = DateTime(local.year, local.month, local.day);
        dueTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }
    String recurrence = task['recurrence'] as String? ?? 'Nenhuma';
    final estCtrl = TextEditingController(text: (task['estimatedMinutes'] != null) ? (task['estimatedMinutes'].toString()) : '');
    final tagsCtrl = TextEditingController(text: (task['tags'] as List?)?.join(', ') ?? '');
    int? reminderMinutes = task['reminderMinutesBefore'] as int?;

    final recurrenceOptions = ['Nenhuma', 'Diária', 'Semanal', 'Mensal'];
    final reminderOptions = <int>[5, 10, 15, 30, 60, 1440];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(4))),
                  Text('Editar tarefa', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 8),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(dueDate == null ? 'Escolher data' : DateFormat('dd/MM/yyyy').format(dueDate!)),
                          onPressed: () async {
                            final picked = await showDatePicker(context: ctx, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
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
                            final picked = await showTimePicker(context: ctx, initialTime: dueTime ?? TimeOfDay.now());
                            if (picked != null) setModalState(() => dueTime = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(labelText: 'Tags (separadas por vírgula, opcional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: reminderMinutes,
                    decoration: const InputDecoration(labelText: 'Lembrete (minutos antes, opcional)'),
                    items: [ const DropdownMenuItem<int?>(value: null, child: Text('Sem lembrete')) ] +
                        reminderOptions.map((m) => DropdownMenuItem<int?>(value: m, child: Text(m == 1440 ? '1 dia antes' : '$m min antes'))).toList(),
                    onChanged: (v) => setModalState(() => reminderMinutes = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar'))),
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

                          final existing = Map<String, dynamic>.from(box.get(key) as Map);
                          existing['title'] = title;
                          existing['description'] = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
                          existing['due'] = due?.toIso8601String();
                          existing['priority'] = priority;
                          existing['recurrence'] = recurrence;
                          existing['estimatedMinutes'] = est;
                          existing['tags'] = tags;
                          existing['reminderMinutesBefore'] = reminderMinutes;
                          box.put(key, existing);
                          Navigator.of(ctx).pop();
                          setState(() {});
                        },
                        child: const Text('Salvar'),
                      )),
                    ],
                  ),
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
        title: const Text('Tarefas'),
        centerTitle: true,
        // actions removido conforme solicitado
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskModal,
        tooltip: 'Nova tarefa',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Filtro de período ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              DropdownButton<TaskPeriod>(
                value: _period,
                items: const [
                  DropdownMenuItem(value: TaskPeriod.today, child: Text('Hoje')),
                  DropdownMenuItem(value: TaskPeriod.week, child: Text('Semana')),
                  DropdownMenuItem(value: TaskPeriod.month, child: Text('Mês')),
                  DropdownMenuItem(value: TaskPeriod.year, child: Text('Ano')),
                  DropdownMenuItem(value: TaskPeriod.custom, child: Text('Personalizado')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  if (v == TaskPeriod.custom) {
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
                hintText: 'Buscar tarefa...',
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
                      const Text('Tarefas', style: TextStyle(fontSize: 12)),
                      Text('${items.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                    Column(children: [
                      const Text('Concluídas', style: TextStyle(fontSize: 12)),
                      Text('$doneCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // ── Lista ───────────────────────────────────────────────────────
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box b, _) {
                final l = _filteredItems();
                if (l.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Nenhuma tarefa em ${_labelForPeriod()}.', textAlign: TextAlign.center),
                    ),
                  );
                }

                // Agrupar por dia
                final grouped = <DateTime, List<Map<String, dynamic>>>{};
                for (var item in l) {
                  final ts = item['_due'] as DateTime;
                  final day = DateTime(ts.year, ts.month, ts.day);
                  grouped.putIfAbsent(day, () => []);
                  grouped[day]!.add(item);
                }
                final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length,
                  itemBuilder: (context, dayIndex) {
                    final day = days[dayIndex];
                    final itemsDay = grouped[day]!;
                    itemsDay.sort((a, b) => (a['_due'] as DateTime).compareTo(b['_due'] as DateTime));
                    final dayLabel = _formatDayLabel(day);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                              const SizedBox(width: 8),
                              Text('${itemsDay.length} tarefa${itemsDay.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        ...itemsDay.map((item) {
                          final key = item['_key'];
                          final ts = item['_due'] as DateTime;
                          final title = item['title'] as String? ?? '';
                          final description = item['description'] as String? ?? '';
                          final isDone = item['isDone'] as bool? ?? false;
                          final priority = item['priority'] as String? ?? 'Média';
                          final est = item['estimatedMinutes'] as int?;
                          final tags = (item['tags'] as List?)?.cast<String>() ?? <String>[];

                          return Dismissible(
                            key: Key('$key-${dayIndex}-${itemsDay.indexOf(item)}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.redAccent,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              box.delete(key);
                              setState(() {});
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                leading: GestureDetector(
                                  onTap: () => _toggleDone(key),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDone ? Colors.green : Colors.transparent,
                                      border: Border.all(color: isDone ? Colors.green : Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: isDone ? const Icon(Icons.check, color: Colors.white, size: 20) : const Icon(Icons.circle_outlined, size: 20),
                                  ),
                                ),
                                title: Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : null, fontWeight: FontWeight.w600, fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDone ? Colors.grey[500] : Colors.grey[700])),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: _priorityColor(priority).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.flag, size: 12, color: _priorityColor(priority)),
                                            const SizedBox(width: 6),
                                            Text(priority, style: const TextStyle(fontSize: 12)),
                                          ]),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.calendar_today, size: 12, color: Colors.blueGrey),
                                            const SizedBox(width: 6),
                                            Text(_formatTime(ts), style: const TextStyle(fontSize: 12)),
                                          ]),
                                        ),
                                        if (est != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.timer, size: 12, color: Colors.purple),
                                              const SizedBox(width: 6),
                                              Text('${est} min', style: const TextStyle(fontSize: 12)),
                                            ]),
                                          ),
                                        if (tags.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: tags.map((t) => Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                              child: Text(t, style: const TextStyle(fontSize: 12)),
                                            )).toList(),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditTask(item, key)),
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(key)),
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