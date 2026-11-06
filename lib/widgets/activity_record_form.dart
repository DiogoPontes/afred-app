// lib/widgets/activity_record_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/workout_plan_screen.dart';

/// Formatter que transforma a digitação de números em uma máscara
/// contínua no formato HH:MM:SS (ex: digitar "130" vira "00:01:30").
class HmsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 6) {
      digits = digits.substring(digits.length - 6);
    }

    String h = '00';
    String m = '00';
    String s = '00';

    if (digits.isEmpty) {
      h = '00';
      m = '00';
      s = '00';
    } else if (digits.length <= 2) {
      s = digits.padLeft(2, '0');
    } else if (digits.length <= 4) {
      s = digits.substring(digits.length - 2);
      m = digits.substring(0, digits.length - 2).padLeft(2, '0');
    } else {
      s = digits.substring(digits.length - 2);
      m = digits.substring(digits.length - 4, digits.length - 2);
      h = digits.substring(0, digits.length - 4).padLeft(2, '0');
    }

    final formatted = '$h:$m:$s';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Resultado do reconhecimento de texto livre do Quick Add.
class ParsedActivityText {
  final String? activityName; // ex: 'Corrida'
  final double? distanceKm; // ex: 4.0
  final String? durationHms; // sempre no formato 'HH:MM:SS'

  const ParsedActivityText({
    this.activityName,
    this.distanceKm,
    this.durationHms,
  });
}

/// Formulário compartilhado de registro de sessão do módulo
/// Atividade Física (fonte única da verdade).
///
/// Usado por:
/// - ActivityScreen (adicionar/editar sessão)
/// - Home > "Adicionar rapidamente" (embedded: true)
/// - Home > editar registro de Atividade Física (embedded: false)
///
/// Salva no box `activity_logs` e sincroniza com o `alfred_box`
/// (chave `activity_<logKey>`), então qualquer mudança aqui aparece
/// automaticamente na Home (e vice-versa).
class ActivityRecordForm extends StatefulWidget {

    static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Reconhece o texto livre digitado no Quick Add.
  /// Ex: "corri 4km em 19:48 minutos" → Corrida, 4 km, 00:19:48.
  static ParsedActivityText parseActivityText(String input) {
    final text = input.toLowerCase();
    if (text.trim().isEmpty) return const ParsedActivityText();

    // 1 - atividade (por enquanto, apenas Corrida)
    String? activityName;
    const corridaSignals = ['corri', 'corrida', 'correr', 'correndo', 'correu'];
    for (final s in corridaSignals) {
      if (text.contains(s)) {
        activityName = 'Corrida';
        break;
      }
    }

    // 2 - distância: "4km", "4 km", "4,5km", "21.5 quilômetros", "5k"
    double? distanceKm;
    final distMatch = RegExp(
      r'(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:kms?|quil[oô]metros?)\b',
    ).firstMatch(text);
    if (distMatch != null) {
      final v = double.tryParse(distMatch.group(1)!.replaceAll(',', '.'));
      if (v != null && v > 0 && v <= 500) distanceKm = v;
    }

    // 3 - tempo (várias formas; a primeira que casar vence)
    String? hms;
    Match? m;

    // 3.1 - hh:mm:ss → "1:52:30"
    m = RegExp(r'\b(\d{1,2}):(\d{2}):(\d{2})\b').firstMatch(text);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final mi = int.parse(m.group(2)!);
      final s = int.parse(m.group(3)!);
      if (h < 24 && mi < 60 && s < 60) {
        hms = '${_twoDigits(h)}:${_twoDigits(mi)}:${_twoDigits(s)}';
      }
    }

    // 3.2 - mm:ss → "19:48" = 19 minutos e 48 segundos
    if (hms == null) {
      m = RegExp(r'\b(\d{1,3}):(\d{2})\b').firstMatch(text);
      if (m != null) {
        final mi = int.parse(m.group(1)!);
        final s = int.parse(m.group(2)!);
        if (mi > 0 && mi < 600 && s < 60) {
          hms = '00:${_twoDigits(mi)}:${_twoDigits(s)}';
        }
      }
    }

    // 3.3 - "1h20", "1h 20min", "2 horas"
    if (hms == null) {
      m = RegExp(r'\b(\d{1,2})\s*h(?:\s*(\d{1,2})\s*(?:min|minutos?)?)?')
          .firstMatch(text);
      if (m != null) {
        final h = int.parse(m.group(1)!);
        final mi = int.tryParse(m.group(2) ?? '') ?? 0;
        if (h > 0 && h < 24 && mi < 60) {
          hms = '${_twoDigits(h)}:${_twoDigits(mi)}:00';
        }
      }
    }

    // 3.4 - "19min48s", "19 min 48 s"
    if (hms == null) {
      m = RegExp(r'\b(\d{1,3})\s*(?:min|minutos?|m)\s*(\d{1,2})\s*(?:s|seg|segs|segundos)?\b')
          .firstMatch(text);
      if (m != null) {
        final mi = int.parse(m.group(1)!);
        final s = int.parse(m.group(2)!);
        if (mi > 0 && mi < 600 && s < 60) {
          hms = '00:${_twoDigits(mi)}:${_twoDigits(s)}';
        }
      }
    }

    // 3.5 - "45 min", "45 minutos"
    if (hms == null) {
      m = RegExp(r'\b(\d{1,3})\s*(?:min|minutos?)\b').firstMatch(text);
      if (m != null) {
        final mi = int.parse(m.group(1)!);
        if (mi > 0 && mi < 600) hms = '00:${_twoDigits(mi)}:00';
      }
    }

    return ParsedActivityText(
      activityName: activityName,
      distanceKm: distanceKm,
      durationHms: hms,
    );
  }

  /// Formata a distância para o campo (ex: 4 → "4", 4.5 → "4,5").
  static String formatDistanceKm(double km) {
    if (km == km.roundToDouble()) return km.round().toString();
    var s = km.toStringAsFixed(2).replaceAll('.', ',');
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith(',')) s = s.substring(0, s.length - 1);
    return s;
  }


  const ActivityRecordForm({
    Key? key,
    this.recordKey,
    this.existing,
    this.embedded = false,
    this.onSaved,
    this.initialRawText = '',
  }) : super(key: key);

  /// Chave do registro no box `activity_logs` (null = novo registro).
  final dynamic recordKey;

  /// Dados do registro sendo editado (formato `activity_logs` ou o
  /// item sincronizado do `alfred_box`).
  final Map<String, dynamic>? existing;

  /// Quando true, o formulário está embutido em outra superfície
  /// (Quick Add da Home) e NÃO fecha nada ao salvar — apenas chama
  /// [onSaved]. Quando false, faz pop do bottom sheet ao salvar.
  final bool embedded;

  /// Chamado após salvar (depois do pop, quando aplicável).
  final VoidCallback? onSaved;

  /// Texto livre digitado no Quick Add (ex: "corri 4km em 19:48").
  /// Usado para pré-preencher atividade, distância e tempo.
  final String initialRawText;

  @override
  State<ActivityRecordForm> createState() => _ActivityRecordFormState();
}

class _ActivityRecordFormState extends State<ActivityRecordForm> {
  final Box _activitiesBox = Hive.box('activities');
  final Box _logsBox = Hive.box('activity_logs');
  final Box _alfredBox = Hive.box('alfred_box');
  final Box _workoutPlansBox = Hive.box('workout_plans');

  late final TextEditingController durationCtrl;
  late final TextEditingController distanceCtrl;
  late final TextEditingController caloriesCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController runTypeCtrl;

  // controle do pré-preenchimento via texto livre do Quick Add
  bool _programmaticFieldSet = false;
  bool _parsedFieldsTouched = false;

  String? selectedActivityKey;
  String selectedActivityName = '';
  String selectedUnit = 'min';

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  String intensity = 'Moderado';
  bool isDone = false;

  String? selectedWorkoutPlanKey;
  String? selectedWorkoutPlanName;
  final Set<String> selectedMuscleGroups = {};
  String? ignoredLogKey;

  static const List<String> availableMuscleGroups = [
    'Peito',
    'Costas',
    'Ombro',
    'Bíceps',
    'Tríceps',
    'Antebraço',
    'Abdômen Infra',
    'Abdômen Supra',
    'Abdômen Lateral',
    'Oblíquo',
    'Quadríceps',
    'Posterior de coxa',
    'Glúteo',
    'Panturrilha',
    'Trapézio',
    'Lombar',
  ];

  @override
  void initState() {
    super.initState();
    _initFromExisting();
  }

  @override
  void didUpdateWidget(covariant ActivityRecordForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // O texto do Quick Add continua sendo digitado depois que o
    // formulário aparece; re-aplica o reconhecimento enquanto o
    // usuário não tiver editado os campos manualmente.
    if (widget.initialRawText != oldWidget.initialRawText) {
      setState(() => _applyInitialRawText());
    }
  }

  @override
  void dispose() {
    durationCtrl.dispose();
    distanceCtrl.dispose();
    caloriesCtrl.dispose();
    notesCtrl.dispose();
    runTypeCtrl.dispose();
    super.dispose();
  }

  void _onParsedFieldEdited() {
    if (_programmaticFieldSet) return;
    _parsedFieldsTouched = true;
  }

  void _setParsedField(TextEditingController c, String text) {
    _programmaticFieldSet = true;
    c.text = text;
    _programmaticFieldSet = false;
  }

  /// Aplica o texto livre do Quick Add aos campos do formulário
  /// (só enquanto o usuário não tiver editado nada manualmente).
  void _applyInitialRawText() {
    if (widget.existing != null) return;
    if (_parsedFieldsTouched) return;

    final parsed = ActivityRecordForm.parseActivityText(widget.initialRawText);
    if (parsed.activityName == null) return;

    // Encontra a atividade cadastrada correspondente (ex: "Corrida")
    Map<String, dynamic>? match;
    for (final a in _availableActivities()) {
      final nome = ((a['name'] as String?) ?? '').toLowerCase();
      if (nome == parsed.activityName!.toLowerCase() ||
          (_isCorrida(nome) && parsed.activityName == 'Corrida')) {
        match = a;
        break;
      }
    }

    // Atividade não cadastrada: não pré-preenche nada
    if (match == null) return;

    selectedActivityKey = match['_key'] as String?;
    selectedActivityName = (match['name'] as String?) ?? parsed.activityName!;
    selectedUnit = (match['unit'] as String?) ?? 'km';

    if (parsed.distanceKm != null) {
      _setParsedField(
        distanceCtrl,
        ActivityRecordForm.formatDistanceKm(parsed.distanceKm!),
      );
    }
    if (parsed.durationHms != null) {
      _setParsedField(durationCtrl, parsed.durationHms!);
    }
  }

  void _initFromExisting() {
    final existing = widget.existing;
    final activities = _availableActivities();

    final existingActivityName =
        existing?['activityName'] as String? ?? '';
    final existingIsCorrida = _isCorrida(existingActivityName);

    durationCtrl = TextEditingController(
      text: existing?['durationMinutes'] != null
          ? (existingIsCorrida
              ? _minutesToHms(
                  (existing!['durationMinutes'] as num).toDouble(),
                )
              : existing!['durationMinutes'].toString())
          : '',
    );

    distanceCtrl = TextEditingController(
      text: existing?['distanceKm'] != null
          ? existing!['distanceKm'].toString()
          : '',
    );

    caloriesCtrl = TextEditingController(
      text: existing?['calories'] != null
          ? existing!['calories'].toString()
          : '',
    );

    notesCtrl = TextEditingController(
      text: existing?['notes'] as String? ?? '',
    );

    runTypeCtrl = TextEditingController(
      text: existing?['runType'] as String? ?? '',
    );

    // Resolve a atividade selecionada. Registros criados pela Home não
    // gravam 'activityKey', então também buscamos pelo nome.
    String? resolvedKey;
    final directKey = existing?['activityKey'] as String?;
    if (directKey != null &&
        activities.any((a) => a['_key'] == directKey)) {
      resolvedKey = directKey;
    } else {
      for (final a in activities) {
        if ((a['name'] as String?) == existingActivityName) {
          resolvedKey = a['_key'] as String?;
          break;
        }
      }
    }

    selectedActivityKey = resolvedKey ??
        (activities.isNotEmpty
            ? activities.first['_key'] as String
            : null);

    selectedActivityName = existingActivityName.isNotEmpty
        ? existingActivityName
        : (activities.isNotEmpty
            ? activities.first['name'] as String
            : '');

    selectedUnit = existing?['unit'] as String? ??
        (activities.isNotEmpty
            ? (activities.first['unit'] as String? ?? 'min')
            : 'min');

    final baseTs = DateTime.tryParse(
          existing?['timestamp'] as String? ?? '',
        ) ??
        DateTime.now();

    selectedDate = DateTime(
      baseTs.year,
      baseTs.month,
      baseTs.day,
    );

    selectedTime = TimeOfDay(
      hour: baseTs.hour,
      minute: baseTs.minute,
    );

    intensity = existing?['intensity'] as String? ?? 'Moderado';
    isDone = existing?['isDone'] as bool? ?? false;

    selectedWorkoutPlanKey = existing?['workoutPlanKey'] as String?;
    selectedWorkoutPlanName = existing?['workoutPlanName'] as String?;

    ignoredLogKey = widget.recordKey?.toString();

    if (existing != null &&
        existing['workoutPlanName'] != null &&
        existing['workoutPlanName'] is String) {
      final wpn = (existing['workoutPlanName'] as String).trim();

      final parts = wpn
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (var p in parts) {
        if (availableMuscleGroups.contains(p)) {
          selectedMuscleGroups.add(p);
        }
      }
    }

    // Pré-preenchimento via texto livre do Quick Add + listeners
    // para saber quando o usuário editar os campos manualmente.
    durationCtrl.addListener(_onParsedFieldEdited);
    distanceCtrl.addListener(_onParsedFieldEdited);

    _applyInitialRawText();
  }

  // ── listas ──────────────────────────────────────────────────────────────

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

    out.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    return out;
  }

  List<Map<String, dynamic>> _availableWorkoutPlans() {
    final out = <Map<String, dynamic>>[];

    for (var k in _workoutPlansBox.keys) {
      final raw = _workoutPlansBox.get(k);

      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = k;
        out.add(m);
      }
    }

    out.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    return out;
  }

  // ── helpers de tipo / formato ───────────────────────────────────────────

  bool _isMusculacao(String activityName) {
    return activityName.toLowerCase().contains('muscula');
  }

  bool _isCorrida(String activityName) {
    return activityName.toLowerCase().contains('corr');
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }

  String _formatPace(double paceMinutesPerKm) {
    if (paceMinutesPerKm <= 0) return '--';

    final totalSeconds = (paceMinutesPerKm * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  double _hmsToMinutes(String hms) {
    final parts = hms.split(':');

    if (parts.length != 3) {
      return _parseNumber(hms) ?? 0.0;
    }

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;

    final totalSeconds = (h * 3600) + (m * 60) + s;

    return totalSeconds / 60.0;
  }

  String _minutesToHms(double minutes) {
    final totalSeconds = (minutes * 60).round();

    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  DateTime? _parseLogDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // ── dias desde o último registro do grupo muscular ──────────────────────

  int? _daysSinceLastMuscleGroupRecord(
    String muscleGroup, {
    dynamic ignoreKey,
  }) {
    DateTime? latestDate;

    for (var key in _logsBox.keys) {
      if (ignoreKey != null &&
          key.toString() == ignoreKey.toString()) {
        continue;
      }

      final raw = _logsBox.get(key);

      if (raw is! Map) continue;

      final log = Map<String, dynamic>.from(raw);
      final activityName = log['activityName'] as String? ?? '';

      if (!_isMusculacao(activityName)) {
        continue;
      }

      final workoutPlanName =
          log['workoutPlanName'] as String? ?? '';

      if (workoutPlanName.isEmpty ||
          !workoutPlanName.contains(muscleGroup)) {
        continue;
      }

      final date = _parseLogDate(log['timestamp']);

      if (date == null || date.isAfter(DateTime.now())) {
        continue;
      }

      if (latestDate == null || date.isAfter(latestDate)) {
        latestDate = date;
      }
    }

    if (latestDate == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastDate = DateTime(
      latestDate.year,
      latestDate.month,
      latestDate.day,
    );

    return today.difference(lastDate).inDays;
  }

  String _lastMuscleGroupRecordLabel(
    String muscleGroup, {
    dynamic ignoreKey,
  }) {
    final days = _daysSinceLastMuscleGroupRecord(
      muscleGroup,
      ignoreKey: ignoreKey,
    );

    if (days == null) {
      return 'Nunca registrado';
    }

    if (days == 0) {
      return 'Registrado hoje';
    }

    if (days == 1) {
      return 'Há 1 dia';
    }

    return 'Há $days dias';
  }

  String muscleGroupsLabel() {
    if (selectedMuscleGroups.isEmpty) {
      return '';
    }

    final list = selectedMuscleGroups.toList();
    list.sort();

    return list.join(', ');
  }

 

  // ── sincronização com alfred_box ────────────────────────────────────────

  void _syncToAlfredBox({
    required String logKey,
    required String activityName,
    required String unit,
    required double? durationMinutes,
    required double? distanceKm,
    required double? calories,
    required double? paceMinutesPerKm,
    required String intensity,
    required String notes,
    required DateTime timestamp,
    required bool isDone,
    String? workoutPlanName,
    required String runType,
  }) {
    final alfredKey = 'activity_$logKey';
    String title = activityName;
    String subtitle = '';

    if (_isMusculacao(activityName)) {
      if (workoutPlanName != null &&
          workoutPlanName.isNotEmpty) {
        subtitle = workoutPlanName;
      }

      if (durationMinutes != null && durationMinutes > 0) {
        subtitle += subtitle.isNotEmpty
            ? ' — ${durationMinutes.toStringAsFixed(0)} min'
            : '${durationMinutes.toStringAsFixed(0)} min';
      }

      if (subtitle.isNotEmpty) title = '$activityName — $subtitle';

    } else if (_isCorrida(activityName)) {
      if (distanceKm != null && distanceKm > 0) {
        title = '$activityName — ${distanceKm.toStringAsFixed(2)} km';
      }

      if (durationMinutes != null && durationMinutes > 0) {
        subtitle = _minutesToHms(durationMinutes);
      }

      if (paceMinutesPerKm != null && paceMinutesPerKm > 0) {
        subtitle += subtitle.isNotEmpty
            ? ' • Pace ${_formatPace(paceMinutesPerKm)}'
            : 'Pace ${_formatPace(paceMinutesPerKm)}';
      }
    } else {
      if (unit == 'min' && durationMinutes != null) {
        subtitle =
            '${durationMinutes.toStringAsFixed(0)} min • $intensity';
      }

      if (unit == 'km' && distanceKm != null) {
        subtitle =
            '${distanceKm.toStringAsFixed(2)} km • $intensity';
      }

      if (calories != null && calories > 0) {
        subtitle +=
            ' • ${calories.toStringAsFixed(0)} kcal';
      }

      if (subtitle.isNotEmpty) title = '$activityName — $subtitle';
    }

    final item = {
      'title': title,
      'module': 'Atividade Física',
      'timestamp': timestamp.toIso8601String(),
      'isDone': isDone,
      'activityLogKey': logKey,
      'activityName': activityName,
      'unit': unit,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
      'calories': calories,
      'paceMinutesPerKm': paceMinutesPerKm,
      'intensity': intensity,
      'notes': notes,
      'workoutPlanName': workoutPlanName,
      'runType': runType,
      // Linha secundária exibida em itálico na Home (mesmo
      // padrão dos registros de Leitura).
      if (subtitle.isNotEmpty) 'secondary': subtitle,
    };

    _alfredBox.put(alfredKey, item);
  }

  // ── adicionar/editar tipo de atividade ──────────────────────────────────

  Future<void> _showAddOrEditActivity({dynamic hiveKey}) async {
    final nameCtrl = TextEditingController();
    String unit = 'min';

    if (hiveKey != null) {
      final existing = Map<String, dynamic>.from(
        _activitiesBox.get(hiveKey) as Map,
      );

      nameCtrl.text = existing['name'] ?? '';
      unit = existing['unit'] ?? 'min';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bctx) {
        return StatefulBuilder(
          builder: (bctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hiveKey == null
                            ? 'Nova atividade'
                            : 'Editar atividade',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da atividade',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: unit,
                        items: const [
                          DropdownMenuItem(
                            value: 'min',
                            child: Text('Minutos (min)'),
                          ),
                          DropdownMenuItem(
                            value: 'km',
                            child: Text('Quilômetros (km)'),
                          ),
                        ],
                        onChanged: (v) => setModal(
                          () => unit = v ?? 'min',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Unidade padrão',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
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
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Informe um nome',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final id = hiveKey ??
                                    DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();

                                _activitiesBox.put(
                                  id,
                                  {
                                    'id': id,
                                    'name': name,
                                    'unit': unit,
                                  },
                                );

                                Navigator.pop(bctx);
                              },
                              child: const Text('Salvar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── salvar ──────────────────────────────────────────────────────────────

  void _save() {
    final name = selectedActivityName.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione ou crie uma atividade',
          ),
        ),
      );
      return;
    }

    final isMusc = _isMusculacao(name);
    final isCorrida = _isCorrida(name);

    if (isMusc && selectedMuscleGroups.isNotEmpty) {
      selectedWorkoutPlanKey = null;
      selectedWorkoutPlanName = muscleGroupsLabel();
    }

    final duration = isCorrida
        ? _hmsToMinutes(durationCtrl.text)
        : (double.tryParse(
              durationCtrl.text.replaceAll(',', '.'),
            ) ??
            0.0);

    final distance = double.tryParse(
          distanceCtrl.text.replaceAll(',', '.'),
        ) ??
        0.0;

    final calories = double.tryParse(
          caloriesCtrl.text.replaceAll(',', '.'),
        ) ??
        0.0;

    double? paceMinutesPerKm;

    if (isCorrida && distance > 0 && duration > 0) {
      paceMinutesPerKm = duration / distance;
    }

    final finalDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final logData = {
      'activityKey': selectedActivityKey,
      'activityName': name,
      'unit': selectedUnit,
      'durationMinutes':
          isCorrida || selectedUnit == 'min'
              ? duration
              : null,
      'distanceKm':
          isCorrida || selectedUnit == 'km'
              ? distance
              : null,
      'paceMinutesPerKm': paceMinutesPerKm,
      'calories': isCorrida
          ? null
          : calories > 0
              ? calories
              : null,
      'intensity': intensity,
      'notes': notesCtrl.text.trim(),
      'timestamp': finalDateTime.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'workoutPlanKey': selectedWorkoutPlanKey,
      'workoutPlanName': selectedWorkoutPlanName,
      'isDone': isDone,
      'runType': isCorrida ? runTypeCtrl.text.trim() : null,
    };

    String logKey2;

    if (widget.existing != null && widget.recordKey != null) {
      _logsBox.put(widget.recordKey, logData);
      logKey2 = widget.recordKey.toString();
    } else {
      final newKey = DateTime.now()
          .millisecondsSinceEpoch
          .toString();

      _logsBox.put(newKey, logData);
      logKey2 = newKey;
    }

    _syncToAlfredBox(
      logKey: logKey2,
      activityName: name,
      unit: selectedUnit,
      durationMinutes:
          isCorrida || selectedUnit == 'min'
              ? duration
              : null,
      distanceKm:
          isCorrida || selectedUnit == 'km'
              ? distance
              : null,
      calories: isCorrida
          ? null
          : calories > 0
              ? calories
              : null,
      paceMinutesPerKm: paceMinutesPerKm,
      intensity: intensity,
      notes: notesCtrl.text.trim(),
      timestamp: finalDateTime,
      isDone: isDone,
      workoutPlanName: selectedWorkoutPlanName,
      runType: isCorrida ? runTypeCtrl.text.trim() : '',
      
    );

    if (!widget.embedded) {
      Navigator.pop(context);
    }

    widget.onSaved?.call();
  }

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activities = _availableActivities();

    final isMusc = _isMusculacao(selectedActivityName);

    final isCorrida = _isCorrida(selectedActivityName);

    final currentDistance = _parseNumber(distanceCtrl.text);

    double? currentDuration;

    if (isCorrida) {
      final parsed = _hmsToMinutes(durationCtrl.text);
      currentDuration = parsed > 0 ? parsed : null;
    } else {
      currentDuration = _parseNumber(durationCtrl.text);
    }

    double? calculatedPace;

    if (isCorrida &&
        currentDistance != null &&
        currentDistance > 0 &&
        currentDuration != null &&
        currentDuration > 0) {
      calculatedPace = currentDuration / currentDistance;
    }

    final plans = _availableWorkoutPlans();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.embedded) ...[
              Text(
                widget.existing != null
                    ? 'Editar sessão'
                    : 'Registrar sessão',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Atividade ────────────────────────────────────────
            DropdownButtonFormField<String?>(
              value: selectedActivityKey,
              items: [
                if (activities.isEmpty)
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Nenhuma atividade definida',
                    ),
                  ),
                ...activities.map(
                  (a) => DropdownMenuItem(
                    value: a['_key'] as String,
                    child: Text(a['name']),
                  ),
                ),
                const DropdownMenuItem(
                  value: '__add_new__',
                  child: Text(
                    'Adicionar nova atividade...',
                  ),
                ),
              ],
              onChanged: (v) async {
                _parsedFieldsTouched = true;
                if (v == '__add_new__') {
                  await _showAddOrEditActivity();

                  if (!mounted) return;

                  setState(() {
                    final updated = _availableActivities();

                    if (updated.isNotEmpty) {
                      selectedActivityKey =
                          updated.first['_key'] as String;
                      selectedActivityName =
                          updated.first['name'] as String;
                      selectedUnit =
                          updated.first['unit'] as String? ??
                              'min';
                    }
                  });
                } else {
                  setState(() {
                    final wasCorrida = _isCorrida(
                      selectedActivityName,
                    );

                    selectedActivityKey = v;

                    if (v != null) {
                      final a = _activitiesBox.get(v) as Map?;

                      if (a != null) {
                        selectedActivityName =
                            a['name'] ?? selectedActivityName;
                        selectedUnit =
                            a['unit'] ?? selectedUnit;
                      }
                    } else {
                      selectedActivityName = '';
                      selectedUnit = 'min';
                    }

                    final nowCorrida = _isCorrida(
                      selectedActivityName,
                    );

                    // Limpa os campos de tempo/distância quando
                    // o tipo (Corrida x demais) muda, para não
                    // manter um valor em formato incompatível.
                    if (wasCorrida != nowCorrida) {
                      durationCtrl.clear();
                      distanceCtrl.clear();
                    }

                    selectedWorkoutPlanKey = null;
                    selectedWorkoutPlanName = null;
                    selectedMuscleGroups.clear();
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Atividade',
              ),
            ),
            const SizedBox(height: 12),

            // ── Treino ───────────────────────────────────────────
            if (isMusc) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(
                    Icons.sports_gymnastics,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Treino',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const WorkoutPlanScreen(),
                        ),
                      );

                      if (mounted) setState(() {});
                    },
                    icon: const Icon(
                      Icons.edit_note,
                      size: 16,
                    ),
                    label: const Text(
                      'Gerenciar treinos',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (plans.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  value: selectedWorkoutPlanKey,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Sem treino específico',
                      ),
                    ),
                    ...plans.map(
                      (p) => DropdownMenuItem(
                        value: p['_key'] as String,
                        child: Text(p['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    selectedWorkoutPlanKey = v;
                    selectedMuscleGroups.clear();

                    if (v != null) {
                      final plan = plans.firstWhere(
                        (p) => p['_key'] == v,
                        orElse: () => {},
                      );

                      String? planName;

                      if (plan is Map &&
                          plan['name'] is String) {
                        planName =
                            plan['name'] as String;
                      }

                      String groupsSuffix = '';

                      try {
                        if (plan is Map &&
                            plan['muscleGroups'] != null) {
                          final mg =
                              plan['muscleGroups'];

                          if (mg is List) {
                            final clean = mg
                                .whereType<String>()
                                .toList();

                            if (clean.isNotEmpty) {
                              groupsSuffix =
                                  ' (${clean.join(', ')})';
                            }
                          } else if (mg is String &&
                              mg.trim().isNotEmpty) {
                            groupsSuffix =
                                ' (${mg.trim()})';
                          }
                        }
                      } catch (_) {
                        groupsSuffix = '';
                      }

                      selectedWorkoutPlanName =
                          planName != null
                              ? '$planName$groupsSuffix'
                              : null;
                    } else {
                      selectedWorkoutPlanName = null;
                    }
                  }),
                  decoration: const InputDecoration(
                    labelText: 'Selecionar treino salvo',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ou selecione grupos musculares '
                  '(sem escolher treino):',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const Text(
                  'Selecione os grupos musculares '
                  'deste treino:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // ── Grupos musculares ──────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableMuscleGroups.map((g) {
                  final selected =
                      selectedMuscleGroups.contains(g);

                  final lastRecordLabel =
                      _lastMuscleGroupRecordLabel(
                    g,
                    ignoreKey: ignoredLogKey,
                  );

                  return FilterChip(
                    selected: selected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          g,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lastRecordLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white.withOpacity(
                                    0.85,
                                  )
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary,
                    checkmarkColor: Colors.white,
                    onSelected: (v) => setState(() {
                      if (v) {
                        selectedMuscleGroups.add(g);
                      } else {
                        selectedMuscleGroups.remove(g);
                      }

                      if (selectedMuscleGroups.isNotEmpty) {
                        selectedWorkoutPlanKey = null;
                        selectedWorkoutPlanName =
                            muscleGroupsLabel();
                      } else {
                        selectedWorkoutPlanName = null;
                      }
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.label,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedWorkoutPlanName != null &&
                              selectedWorkoutPlanName!
                                  .isNotEmpty
                          ? 'Nome do registro: '
                              '$selectedWorkoutPlanName'
                          : 'Nome do registro: (nenhum)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(),
              const SizedBox(height: 4),
            ],

            // ── Duração / distância ─────────────────────────────
            if (isCorrida) ...[
              TextField(
                controller: distanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Distância (km)',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: runTypeCtrl,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tipo de corrida',
                  hintText: 'Ex.: 5 min a 5,5 km/h + 5 km a 9,5 km/h',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [HmsInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Tempo (hh:mm:ss)',
                  hintText: '00:00:00',
                ),
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed),
                    const SizedBox(width: 8),
                    Text(
                      calculatedPace != null
                          ? 'Pace: ${_formatPace(calculatedPace)}'
                          : 'Pace: informe distância e tempo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (selectedUnit == 'min') ...[
              TextField(
                controller: durationCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Duração (minutos)',
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              TextField(
                controller: distanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distância (km)',
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Campos comuns ───────────────────────────────────
            if (!isMusc && !isCorrida) ...[
              TextField(
                controller: caloriesCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Calorias (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: intensity,
                items: const [
                  DropdownMenuItem(
                    value: 'Leve',
                    child: Text('Leve'),
                  ),
                  DropdownMenuItem(
                    value: 'Moderado',
                    child: Text('Moderado'),
                  ),
                  DropdownMenuItem(
                    value: 'Intenso',
                    child: Text('Intenso'),
                  ),
                ],
                onChanged: (v) => setState(
                  () => intensity = v ?? 'Moderado',
                ),
                decoration: const InputDecoration(
                  labelText: 'Intensidade',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Realizado ───────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Marcar como realizado',
              ),
              subtitle: Text(
                isDone
                    ? 'Sessão concluída ✓'
                    : 'Ainda não realizada',
              ),
              value: isDone,
              secondary: Icon(
                isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    isDone ? Colors.green : Colors.grey,
              ),
              onChanged: (v) => setState(
                () => isDone = v,
              ),
            ),

            const SizedBox(height: 8),

            // ── Data + hora ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setState(
                          () => selectedDate = picked,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.calendar_today,
                      size: 16,
                    ),
                    label: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/'
                      '${selectedDate.month.toString().padLeft(2, '0')}/'
                      '${selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(
                              alwaysUse24HourFormat: true,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        setState(
                          () => selectedTime = picked,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.access_time,
                      size: 16,
                    ),
                    label: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:'
                      '${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Botões ──────────────────────────────────────────
            Row(
              children: [
                if (!widget.embedded) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(
                      widget.existing != null
                          ? 'Salvar'
                          : 'Registrar',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}