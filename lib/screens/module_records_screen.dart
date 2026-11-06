// lib/screens/module_records_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/day_records.dart';
import 'finance_screen.dart';
import '../widgets/finance_record_form.dart';
import '../widgets/activity_record_form.dart';
import 'activity_screen.dart';
import 'study_screen.dart';
import 'reading_screen.dart';

/// Segunda tela da nova Home: mostra somente os registros do módulo
/// escolhido no dashboard, do mais recente para o mais antigo.
class ModuleRecordsScreen extends StatefulWidget {
  const ModuleRecordsScreen({
    Key? key,
    required this.module,
    required this.date,
  }) : super(key: key);

  final String module;
  final DateTime date;

  @override
  State<ModuleRecordsScreen> createState() => _ModuleRecordsScreenState();
}

class _ModuleRecordsScreenState extends State<ModuleRecordsScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box');
  }

  dynamic _dynamicKey(String s) => int.tryParse(s) ?? s;

  List<Map<String, dynamic>> get _moduleItems {
    final all = itemsForDay(widget.date);
    return all
        .where((it) => (it['module'] as String? ?? '') == widget.module)
        .toList();
  }

  // ── Toggle concluído ──

  void _toggleDone(Map<String, dynamic> item) {
    final keyStr = item['_key'].toString();
    final isDone = item['isDone'] as bool? ?? false;

    if (keyStr.startsWith('reading_')) {
      final actKey = _dynamicKey(keyStr.replaceFirst('reading_', ''));
      final activitiesBox = Hive.box('alfred_reading_activities');
      final raw = activitiesBox.get(actKey);
      if (raw == null) return;
      final updated = Map<String, dynamic>.from(raw as Map);
      updated['isDone'] = !isDone;
      activitiesBox.put(actKey, updated);
    } else if (keyStr.startsWith('study_activity_')) {
      final actKey = _dynamicKey(keyStr.replaceFirst('study_activity_', ''));
      final activitiesBox = Hive.box('alfred_study_activities');
      final raw = activitiesBox.get(actKey);
      if (raw == null) return;
      final updated = Map<String, dynamic>.from(raw as Map);
      updated['isDone'] = !isDone;
      activitiesBox.put(actKey, updated);
    } else if (keyStr.startsWith('study_schedule_')) {
      final schedKey = keyStr.replaceFirst('study_schedule_', '');
      final dayKey = DateFormat('yyyyMMdd').format(
        DateTime(widget.date.year, widget.date.month, widget.date.day),
      );
      final overrideKey = 'study_done_${schedKey}_$dayKey';
      if (box.containsKey(overrideKey)) {
        box.delete(overrideKey);
      } else {
        box.put(overrideKey, {
          'isDone': true,
          'datetimeMillis': (item['_ts'] as DateTime).millisecondsSinceEpoch,
          'scheduleKey': schedKey,
          'scheduledDay': dayKey,
        });
      }
    } else {
      final recordKey = _dynamicKey(keyStr);
      final raw = box.get(recordKey);
      if (raw == null) return;
      final updated = Map<String, dynamic>.from(raw as Map);
      updated['isDone'] = !isDone;
      box.put(recordKey, updated);
    }

    setState(() {});
  }

  // ── Excluir ──

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro'),
        content: const Text('Deseja excluir este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final keyStr = item['_key'].toString();
    if (keyStr.startsWith('reading_')) {
      await Hive.box('alfred_reading_activities')
          .delete(_dynamicKey(keyStr.replaceFirst('reading_', '')));
    } else if (keyStr.startsWith('study_activity_')) {
      await Hive.box('alfred_study_activities')
          .delete(_dynamicKey(keyStr.replaceFirst('study_activity_', '')));
    } else {
      await box.delete(_dynamicKey(keyStr));
    }
    if (mounted) setState(() {});
  }

  // ── Editar ──

  Future<void> _showEditItem(Map<String, dynamic> item) async {
    final module = widget.module;
    final keyStr = item['_key'].toString();
    if (module == 'Atividade Física') {
      final logKey = item['activityLogKey'];

      if (logKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Esta sessão não está vinculada ao registro de atividade.',
            ),
          ),
        );
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(
            initialEditLogKey: logKey,
          ),
        ),
      );

      if (mounted) setState(() {});
      return;
    }
    if (module == 'Estudos') {
      final actKeyStr = keyStr.replaceFirst('study_activity_', '');
      final actKey = _dynamicKey(actKeyStr);

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => StudyScreen(initialEditActivityKey: actKey),
        ),
      );

      if (mounted) setState(() {});
      return;
    }
    if (module == 'Leitura') {
      final actKey = _dynamicKey(keyStr.replaceFirst('reading_', ''));

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReadingScreen(initialEditActivityKey: actKey),
        ),
      );

      if (mounted) setState(() {});
      return;
    }
    final isReading = keyStr.startsWith('reading_');

    final titleCtrl =
        TextEditingController(text: item['title']?.toString() ?? '');
    final amountCtrl = TextEditingController(text: () {
      final v = financeAmountOf(item);
      return v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');
    }());
    bool isIncome = item['isIncome'] == true;
    String priority = item['priority']?.toString() ?? 'Média';
    final durationCtrl = TextEditingController(text: () {
      final s = (item['durationSeconds'] as num?)?.toInt() ?? 0;
      return s > 0 ? formatHms(s) : '';
    }());
    final distanceCtrl = TextEditingController(text: () {
      final d = activityDistanceKmOf(item);
      return d == null ? '' : d.toString().replaceAll('.', ',');
    }());
    final pageCtrl = TextEditingController(text: () {
      final p = (item['page'] as num?)?.toInt() ?? 0;
      return p > 0 ? p.toString() : '';
    }());
    final minutesCtrl = TextEditingController(text: () {
      final s = (item['durationSeconds'] as num?)?.toInt() ?? 0;
      return s > 0 ? (s ~/ 60).toString() : '';
    }());

    bool isReadingAudio = false;
    if (isReading) {
      try {
        final actKey = _dynamicKey(keyStr.replaceFirst('reading_', ''));
        final actRaw = Hive.box('alfred_reading_activities').get(actKey);
        if (actRaw is Map) {
          final act = Map<String, dynamic>.from(actRaw);
          final bookRaw = act['bookKey'] != null
              ? Hive.box('alfred_reading_books').get(act['bookKey'])
              : null;
          isReadingAudio = readingBookIsAudio(
            bookRaw is Map ? Map<String, dynamic>.from(bookRaw) : null,
          );
        }
      } catch (_) {}
    }

    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar registro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isReading)
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                if (module == 'Finanças') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'Valor (R\$)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('É receita?'),
                    value: isIncome,
                    onChanged: (v) => setDialogState(() => isIncome = v),
                  ),
                ],
                if (module == 'Tarefas') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration:
                        const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      DropdownMenuItem(value: 'Média', child: Text('Média')),
                      DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      if (v != null) priority = v;
                    }),
                  ),
                ],
                if (module == 'Atividade Física') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Duração (HH:MM:SS)',
                      hintText: '00:19:48',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: distanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Distância (km)',
                      hintText: '4',
                    ),
                  ),
                ],
                if (isReading) ...[
                  const SizedBox(height: 12),
                  if (isReadingAudio)
                    TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Minutos lidos'),
                    )
                  else
                    TextField(
                      controller: pageCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Página'),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final changes = <String, dynamic>{};
                if (module == 'Finanças') {
                  final raw = amountCtrl.text.trim().replaceAll(',', '.');
                  final v = double.tryParse(raw);
                  if (v != null) {
                    changes[financeAmountKeyOf(item) ?? 'value'] = v;
                  }
                  changes['isIncome'] = isIncome;
                  final desc = titleCtrl.text.trim();
                  if (desc.isNotEmpty) changes['title'] = desc;
                } else if (module == 'Atividade Física') {
                  final secs = _parseHms(durationCtrl.text.trim());
                  if (secs != null) changes['durationSeconds'] = secs;
                  final dist = double.tryParse(
                    distanceCtrl.text.trim().replaceAll(',', '.'),
                  );
                  if (dist != null) {
                    changes[activityDistanceKeyOf(item) ?? 'distanceKm'] =
                        dist;
                  }
                  final t = titleCtrl.text.trim();
                  if (t.isNotEmpty) changes['title'] = t;
                } else if (isReading) {
                  if (isReadingAudio) {
                    final mins = int.tryParse(minutesCtrl.text.trim());
                    if (mins != null) {
                      changes['durationSeconds'] = mins * 60;
                    }
                  } else {
                    final p = int.tryParse(pageCtrl.text.trim());
                    if (p != null) changes['page'] = p;
                  }
                } else if (module == 'Tarefas') {
                  changes['priority'] = priority;
                  final t = titleCtrl.text.trim();
                  if (t.isNotEmpty) changes['title'] = t;
                } else {
                  final t = titleCtrl.text.trim();
                  if (t.isNotEmpty) changes['title'] = t;
                }
                Navigator.of(ctx).pop(changes);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (changes is Map<String, dynamic> && changes.isNotEmpty) {
      await _persistEdit(item, changes);
    }
  }

  Future<void> _persistEdit(
    Map<String, dynamic> item,
    Map<String, dynamic> changes,
  ) async {
    final keyStr = item['_key'].toString();
    if (keyStr.startsWith('reading_')) {
      final actKey = _dynamicKey(keyStr.replaceFirst('reading_', ''));
      final activitiesBox = Hive.box('alfred_reading_activities');
      final raw = activitiesBox.get(actKey);
      if (raw == null) return;
      final updated = Map<String, dynamic>.from(raw as Map);
      changes.forEach((k, v) => updated[k] = v);
      await activitiesBox.put(actKey, updated);
    } else {
      // Atividade Física: reflete duração/distância também no log real.
      final logKey = item['activityLogKey'];
      if ((item['module']?.toString() ?? '') == 'Atividade Física' &&
          logKey != null) {
        try {
          final logsBox = Hive.box('activity_logs');
          dynamic raw = logsBox.get(logKey);
          dynamic effectiveKey = logKey;
          if (raw == null) {
            final asInt = int.tryParse(logKey.toString());
            if (asInt != null) {
              raw = logsBox.get(asInt);
              effectiveKey = asInt;
            }
          }
          if (raw is Map) {
            final log = Map<String, dynamic>.from(raw);
            var changed = false;
            for (final k in const [
              'durationSeconds',
              'distanceKm',
              'distance',
              'km',
            ]) {
              if (changes[k] != null) {
                log[k] = changes[k];
                changed = true;
              }
            }
            if (changed) await logsBox.put(effectiveKey, log);
          }
        } catch (_) {}
      }

      final recordKey = _dynamicKey(keyStr);
      final raw = box.get(recordKey);
      if (raw == null) return;
      final updated = Map<String, dynamic>.from(raw as Map);
      changes.forEach((k, v) => updated[k] = v);
      await box.put(recordKey, updated);
    }
    if (mounted) setState(() {});
  }

  int? _parseHms(String text) {
    if (text.isEmpty) return null;
    final nums = <int>[];
    for (final p in text.split(':')) {
      final v = int.tryParse(p.trim());
      if (v == null) return null;
      nums.add(v);
    }
    int s = 0;
    for (final n in nums) {
      s = s * 60 + n;
    }
    return s;
  }

  // ── Adicionar registro (formulários compartilhados) ──

  Future<void> _openAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Adicionar em ${widget.module}',
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.module == 'Finanças')
                FinanceRecordForm(
                  key: const ValueKey('module_add_finance_form'),
                  embedded: true,
                  initialDescription: null,
                  initialRawText: '',
                  onSaved: () => Navigator.of(sheetCtx).pop(),
                  availableCards: availableFinanceCards,
                  showCardForm: (hiveKey) =>
                      showFinanceCardForm(sheetCtx, hiveKey),
                )
              else if (widget.module == 'Atividade Física')
                ActivityRecordForm(
                  key: const ValueKey('module_add_activity_form'),
                  embedded: true,
                  initialRawText: '',
                  onSaved: () => Navigator.of(sheetCtx).pop(),
                )
              else
                _SimpleModuleRecordForm(
                  module: widget.module,
                  date: widget.date,
                  onSaved: () => Navigator.of(sheetCtx).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card do registro ──

  Widget _leadingFor(String module, bool isDone) {
    if (isDone) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.blueGrey,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.check, color: Colors.white, size: 20),
        ),
      );
    }
    final color = moduleColorOf(module);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Icon(moduleIconOf(module), color: Colors.white, size: 20),
      ),
    );
  }

  /// "Treino A (Peito, Tríceps)" -> grupos [Peito, Tríceps]
  /// "Peito, Costas"             -> grupos [Peito, Costas]
  ({String? plan, List<String> groups}) _parseWorkout(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == 'null') {
      return (plan: null, groups: []);
    }

    String? plan;
    String groupsText = text;
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    if (open > 0 && close > open) {
      plan = text.substring(0, open).trim();
      groupsText = text.substring(open + 1, close);
    }

    final groups = groupsText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return (plan: plan, groups: groups);
  }

  Widget? _activityDetails(Map<String, dynamic> item) {
    final name = item['activityName']?.toString() ?? activityTypeOf(item);
    final lower = name.toLowerCase();
    final isMusc = lower.contains('muscula');
    final isRun = lower.contains('corr');

    int secs = (item['durationSeconds'] as num?)?.toInt() ?? 0;
    if (secs == 0 && item['durationMinutes'] is num) {
      secs = ((item['durationMinutes'] as num).toDouble() * 60).round();
    }

    final dist = activityDistanceKmOf(item);
    final calories = (item['calories'] as num?)?.toDouble();
    final intensity = item['intensity']?.toString();
    final notes = item['notes']?.toString().trim() ?? '';
    final parts = <String>[];

    if (isRun) {
      if (dist != null && dist > 0) {
        parts.add('${ActivityRecordForm.formatDistanceKm(dist)}km');
      }
      if (secs > 0) {
        parts.add(formatHms(secs));
      }
      if (dist != null && dist > 0 && secs > 0) {
        // formatPace pode devolver null e/ou já incluir o sufixo "/km"
        final pace =
            (formatPace(secs, dist) ?? '').replaceAll('/km', '').trim();
        if (pace.isNotEmpty) parts.add('pace $pace /km');
      }
    } else if (isMusc) {
      final workout = _parseWorkout(
        item['workoutPlanName']?.toString() ?? '',
      );
      parts.addAll(workout.groups.map((group) => group.toLowerCase()));
      if (secs > 0) {
        parts.add('${(secs / 60).round()} min');
      }
    } else {
      if (secs > 0) {
        parts.add('${(secs / 60).round()} min');
      }
      if (dist != null && dist > 0) {
        parts.add('${ActivityRecordForm.formatDistanceKm(dist)}km');
      }
      if (calories != null && calories > 0) {
        parts.add('${calories.round()} kcal');
      }
      if (intensity != null && intensity.isNotEmpty && intensity != 'null') {
        parts.add(intensity);
      }
    }

    if (parts.isEmpty && notes.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join(' | '),
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              notes,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _recordCard(Map<String, dynamic> item) {
    final module = widget.module;
    final color = moduleColorOf(module);
    final isActivity = module == 'Atividade Física';
    final isDone = item['isDone'] as bool? ?? false;
    final ts = item['_ts'] as DateTime;
    final timeLabel =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    final isOverdue = item['_isOverdue'] == true;
    final readOnly = item['_readOnly'] == true;
    final canToggle =
        module == 'Tarefas' || module == 'Leitura' || module == 'Estudos';

    String title = item['title']?.toString() ?? '';
    String? secondary;
    String? amountText;
    Color amountColor = Colors.grey;
    Widget? activityDetails;

    if (module == 'Finanças') {
      final amount = financeAmountOf(item);
      final isIncome = item['isIncome'] == true;
      if (amount != null) {
        amountColor = isIncome ? Colors.green : Colors.redAccent;
        amountText = '${isIncome ? '+' : '-'} ${formatBRL(amount.abs())}';
      }

      final detailParts = <String>[];
      final category = item['category']?.toString();
      if (category != null && category.isNotEmpty && category != 'null') {
        detailParts.add(category);
      }
      final card = item['card']?.toString() ?? item['cardName']?.toString();
      if (card != null && card.isNotEmpty && card != 'null') {
        detailParts.add(card);
      }
      final installments = item['installmentTotal'] ?? item['installments'];
      if (installments is num && installments.toInt() > 1) {
        detailParts.add('${installments.toInt()}x');
      }
      if (detailParts.isNotEmpty) secondary = detailParts.join(' • ');
    } else if (isActivity) {
      title = item['activityName']?.toString() ?? activityTypeOf(item);
      activityDetails = _activityDetails(item);
      secondary = null;
    } else if (module == 'Leitura') {
      final progress = item['_readingProgress']?.toString();
      secondary = (progress == null || progress.isEmpty) ? null : progress;
    } else if (module == 'Estudos') {
      final progress = item['_studyProgress']?.toString().trim() ?? '';
      final notes = item['notes']?.toString().trim() ?? '';

      final detailParts = <String>[
        if (progress.isNotEmpty) progress,
        if (notes.isNotEmpty) notes,
      ];

      secondary = detailParts.isEmpty ? null : detailParts.join(' • ');
    }

    final priority = module == 'Tarefas' ? item['priority']?.toString() : null;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: canToggle ? () => _toggleDone(item) : null,
        leading: _leadingFor(module, isDone),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isActivity ? 15 : null,
                      color: isActivity ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                      decoration: (isDone && module == 'Tarefas')
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (amountText != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                      softWrap: true,
                    ),
                  ),
              ],
            ),
            if (secondary != null && secondary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  secondary,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (activityDetails != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: activityDetails,
              ),
            if (priority != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColorOf(priority).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          fontSize: 11,
                          color: priorityColorOf(priority),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isOverdue ? '$timeLabel • atrasado' : timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isActivity
                      ? Colors.white70
                      : (isOverdue ? Colors.redAccent : Colors.grey),
                ),
              ),
            ),
          ],
        ),
        trailing: readOnly
            ? null
            : PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: 'Mais',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') {
                    _showEditItem(item);
                  } else if (v == 'delete') {
                    _confirmDelete(item);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final color = moduleColorOf(widget.module);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Icon(
                  moduleIconOf(widget.module),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.module,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dayLabelOf(widget.date, showToday: _isToday),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Adicionar registro',
            icon: const Icon(Icons.add),
            onPressed: _openAddSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: recordsListenable(),
          builder: (context, _) {
            final items = _moduleItems;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'registro' : 'registros'} • mais recentes primeiro',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                moduleIconOf(widget.module),
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhum registro deste módulo neste dia',
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) => _recordCard(items[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

bool _isTodayHelper(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

extension on _ModuleRecordsScreenState {
  bool get _isToday => _isTodayHelper(widget.date);
}

/// Formulário simples para módulos sem formulário compartilhado
/// (mesmo comportamento do "Salvar em [módulo]" do Quick Add).
class _SimpleModuleRecordForm extends StatefulWidget {
  const _SimpleModuleRecordForm({
    required this.module,
    required this.date,
    required this.onSaved,
  });

  final String module;
  final DateTime date;
  final VoidCallback onSaved;

  @override
  State<_SimpleModuleRecordForm> createState() =>
      _SimpleModuleRecordFormState();
}

class _SimpleModuleRecordFormState extends State<_SimpleModuleRecordForm> {
  final TextEditingController textCtrl = TextEditingController();

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final text = textCtrl.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final ts = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      now.hour,
      now.minute,
    );

    Hive.box('alfred_box').add({
      'title': text,
      'module': widget.module,
      'timestamp': ts.toIso8601String(),
      'isDone': false,
      if (widget.module == 'Tarefas') 'priority': 'Média',
    });

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Texto',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text('Salvar em ${widget.module}'),
          ),
        ),
      ],
    );
  }
}