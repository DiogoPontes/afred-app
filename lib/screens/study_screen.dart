// lib/screens/study_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import 'focus_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

// ═══════════════════════════════════════════════════════════════════════════
// Modelos
// ═══════════════════════════════════════════════════════════════════════════

class StudyType {
  final dynamic key;
  String name;
  String description;
  int totalLessons;
  String category;
  final int createdAt;

  StudyType({
    this.key,
    required this.name,
    this.description = '',
    required this.totalLessons,
    this.category = '',
    required this.createdAt,
  });

  factory StudyType.fromHive(dynamic key, dynamic raw) {
    final m = _asMap(raw);

    return StudyType(
      key: key,
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      totalLessons: _asInt(m['totalLessons']),
      category: m['category']?.toString() ?? '',
      createdAt: _asInt(
        m['createdAt'],
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toHive() {
    return {
      'name': name,
      'description': description,
      'totalLessons': totalLessons,
      'category': category,
      'createdAt': createdAt,
    };
  }

  StudyType copy() {
    return StudyType(
      key: key,
      name: name,
      description: description,
      totalLessons: totalLessons,
      category: category,
      createdAt: createdAt,
    );
  }
}

class StudyDiscipline {
  final dynamic key;
  dynamic studyTypeKey;
  String name;
  String description;
  int totalLessons;
  final int createdAt;

  StudyDiscipline({
    this.key,
    required this.studyTypeKey,
    required this.name,
    this.description = '',
    required this.totalLessons,
    required this.createdAt,
  });

  factory StudyDiscipline.fromHive(dynamic key, dynamic raw) {
    final m = _asMap(raw);

    return StudyDiscipline(
      key: key,
      studyTypeKey: m['studyTypeKey'],
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      totalLessons: _asInt(m['totalLessons']),
      createdAt: _asInt(
        m['createdAt'],
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toHive() {
    return {
      'studyTypeKey': studyTypeKey,
      'name': name,
      'description': description,
      'totalLessons': totalLessons,
      'createdAt': createdAt,
    };
  }

  StudyDiscipline copy() {
    return StudyDiscipline(
      key: key,
      studyTypeKey: studyTypeKey,
      name: name,
      description: description,
      totalLessons: totalLessons,
      createdAt: createdAt,
    );
  }
}

class StudyActivity {
  final dynamic key;
  dynamic studyTypeKey;
  dynamic studyDisciplineKey;
  int currentLesson;
  int durationMinutes;
  String notes;
  int datetimeMillis;
  bool isDone;
  int revisionCount;

  StudyActivity({
    this.key,
    required this.studyTypeKey,
    this.studyDisciplineKey,
    required this.currentLesson,
    this.durationMinutes = 0,
    this.notes = '',
    required this.datetimeMillis,
    this.isDone = false,
    this.revisionCount = 0,
  });

  factory StudyActivity.fromHive(dynamic key, dynamic raw) {
    final m = _asMap(raw);

    return StudyActivity(
      key: key,
      studyTypeKey: m['studyTypeKey'],
      studyDisciplineKey: m['studyDisciplineKey'],
      currentLesson: _asInt(m['currentLesson']),
      durationMinutes: _asInt(m['durationMinutes']),
      notes: m['notes']?.toString() ?? '',
      datetimeMillis: _asInt(
        m['datetimeMillis'],
        DateTime.now().millisecondsSinceEpoch,
      ),
      isDone: m['isDone'] == true,
      revisionCount: _asInt(m['revisionCount']),
    );
  }

  Map<String, dynamic> toHive() {
    return {
      'studyTypeKey': studyTypeKey,
      'studyDisciplineKey': studyDisciplineKey,
      'currentLesson': currentLesson,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'datetimeMillis': datetimeMillis,
      'isDone': isDone,
      'revisionCount': revisionCount,
    };
  }

  DateTime get datetime {
    return DateTime.fromMillisecondsSinceEpoch(datetimeMillis).toLocal();
  }

  StudyActivity copy() {
    return StudyActivity(
      key: key,
      studyTypeKey: studyTypeKey,
      studyDisciplineKey: studyDisciplineKey,
      currentLesson: currentLesson,
      durationMinutes: durationMinutes,
      notes: notes,
      datetimeMillis: datetimeMillis,
      isDone: isDone,
      revisionCount: revisionCount,
    );
  }
}

class StudySchedule {
  final dynamic key;
  dynamic studyTypeKey;
  dynamic studyDisciplineKey;
  List<int> weekdays;
  int timeHour;
  int timeMinute;
  int notifyMinutesBefore;
  final int createdAt;
  bool isActive;

  StudySchedule({
    this.key,
    required this.studyTypeKey,
    this.studyDisciplineKey,
    required this.weekdays,
    required this.timeHour,
    required this.timeMinute,
    this.notifyMinutesBefore = 15,
    required this.createdAt,
    this.isActive = true,
  });

  factory StudySchedule.fromHive(dynamic key, dynamic raw) {
    final m = _asMap(raw);

    final weekdays = (m['weekdays'] as List?)
            ?.map((value) => _asInt(value))
            .toList() ??
        <int>[];

    return StudySchedule(
      key: key,
      studyTypeKey: m['studyTypeKey'],
      studyDisciplineKey: m['studyDisciplineKey'],
      weekdays: weekdays,
      timeHour: _asInt(m['timeHour']),
      timeMinute: _asInt(m['timeMinute']),
      notifyMinutesBefore: _asInt(m['notifyMinutesBefore'], 15),
      createdAt: _asInt(
        m['createdAt'],
        DateTime.now().millisecondsSinceEpoch,
      ),
      isActive: m['isActive'] != false,
    );
  }

  Map<String, dynamic> toHive() {
    return {
      'studyTypeKey': studyTypeKey,
      'studyDisciplineKey': studyDisciplineKey,
      'weekdays': weekdays,
      'timeHour': timeHour,
      'timeMinute': timeMinute,
      'notifyMinutesBefore': notifyMinutesBefore,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }

  String get timeLabel {
    return '${timeHour.toString().padLeft(2, '0')}:'
        '${timeMinute.toString().padLeft(2, '0')}';
  }

  StudySchedule copy() {
    return StudySchedule(
      key: key,
      studyTypeKey: studyTypeKey,
      studyDisciplineKey: studyDisciplineKey,
      weekdays: List<int>.from(weekdays),
      timeHour: timeHour,
      timeMinute: timeMinute,
      notifyMinutesBefore: notifyMinutesBefore,
      createdAt: createdAt,
      isActive: isActive,
    );
  }
}

enum SessionFilter { all, week, month, year }

// ═══════════════════════════════════════════════════════════════════════════
// Tela principal
// ═══════════════════════════════════════════════════════════════════════════

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    Key? key,
    this.initialEditActivityKey,
  }) : super(key: key);

  final dynamic initialEditActivityKey;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final Box _typesBox;
  late final Box _disciplinesBox;
  late final Box _activitiesBox;
  late final Box _schedulesBox;

  SessionFilter _sessionFilter = SessionFilter.all;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  dynamic _selectedStudyTypeKey;
  dynamic _selectedDisciplineKey;

  final _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final _monthFormatter = DateFormat('MMMM', 'pt_BR');

  final Map<int, String> _weekdayNames = const {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _typesBox = Hive.box('alfred_study_types');
    _disciplinesBox = Hive.box('alfred_study_disciplines');
    _activitiesBox = Hive.box('alfred_study_activities');
    _schedulesBox = Hive.box('alfred_study_schedules');

    if (widget.initialEditActivityKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialEditActivity();
      });
    }
  }

  Future<void> _openInitialEditActivity() async {
    final requestedKey = widget.initialEditActivityKey;
    if (requestedKey == null) return;

    dynamic actKey = requestedKey;
    dynamic raw = _activitiesBox.get(actKey);

    // Tenta a representação alternativa da chave (String ↔ int),
    // para cobrir chaves antigas salvas de forma diferente.
    if (raw == null && requestedKey is String) {
      final parsed = int.tryParse(requestedKey);
      if (parsed != null) {
        final parsedRaw = _activitiesBox.get(parsed);
        if (parsedRaw != null) {
          actKey = parsed;
          raw = parsedRaw;
        }
      }
    } else if (raw == null && requestedKey is int) {
      final stringKey = requestedKey.toString();
      final stringRaw = _activitiesBox.get(stringKey);
      if (stringRaw != null) {
        actKey = stringKey;
        raw = stringRaw;
      }
    }

    if (raw is! Map) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível localizar esta sessão de estudo.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final activity = StudyActivity.fromHive(actKey, raw);

    // Ao fundo do formulário, mostra a aba de Sessões.
    _tabController.animateTo(1);

    await _showActivityForm(existing: activity);

    // Esta tela foi aberta apenas para editar a sessão; ao fechar o
    // formulário, volta para a lista de registros.
    if (mounted) {
      setState(() {});
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Getters e helpers
  // ═══════════════════════════════════════════════════════════════════════

  String _fmtDateTime(int millis) {
    return _dateFormatter.format(
      DateTime.fromMillisecondsSinceEpoch(millis).toLocal(),
    );
  }

  List<StudyType> get _studyTypes {
    final result = _typesBox.keys
        .map((key) => StudyType.fromHive(key, _typesBox.get(key)))
        .toList();

    result.sort((a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ));

    return result;
  }

  List<StudyDiscipline> get _disciplines {
    final result = _disciplinesBox.keys
        .map(
          (key) => StudyDiscipline.fromHive(
            key,
            _disciplinesBox.get(key),
          ),
        )
        .toList();

    result.sort((a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ));

    return result;
  }

  List<StudyActivity> get _activities {
    final result = _activitiesBox.keys
        .map(
          (key) => StudyActivity.fromHive(
            key,
            _activitiesBox.get(key),
          ),
        )
        .toList();

    result.sort(
      (a, b) => b.datetimeMillis.compareTo(a.datetimeMillis),
    );

    return result;
  }

  List<StudySchedule> get _schedules {
    return _schedulesBox.keys
        .map(
          (key) => StudySchedule.fromHive(
            key,
            _schedulesBox.get(key),
          ),
        )
        .toList();
  }

  List<StudyDiscipline> _disciplinesForCourse(dynamic courseKey) {
    return _disciplines
        .where((discipline) => discipline.studyTypeKey == courseKey)
        .toList();
  }

  StudyType? _typeByKey(dynamic key) {
    final raw = _typesBox.get(key);
    if (raw == null) return null;

    return StudyType.fromHive(key, raw);
  }

  StudyDiscipline? _disciplineByKey(dynamic key) {
    if (key == null) return null;

    final raw = _disciplinesBox.get(key);
    if (raw == null) return null;

    return StudyDiscipline.fromHive(key, raw);
  }

  StudyActivity? _lastActivityForType(dynamic typeKey) {
    for (final activity in _activities) {
      if (activity.studyTypeKey == typeKey) {
        return activity;
      }
    }

    return null;
  }

  StudyActivity? _lastActivityForDiscipline(dynamic disciplineKey) {
    for (final activity in _activities) {
      if (activity.studyDisciplineKey == disciplineKey) {
        return activity;
      }
    }

    return null;
  }

  int _totalMinutesForType(dynamic typeKey) {
    return _activities
        .where((activity) => activity.studyTypeKey == typeKey)
        .fold(
          0,
          (total, activity) => total + activity.durationMinutes,
        );
  }

  int _totalMinutesForDiscipline(dynamic disciplineKey) {
    return _activities
        .where(
          (activity) => activity.studyDisciplineKey == disciplineKey,
        )
        .fold(
          0,
          (total, activity) => total + activity.durationMinutes,
        );
  }

  int _progressForType(dynamic typeKey) {
    final disciplineKeys = _disciplinesForCourse(typeKey)
        .map((discipline) => discipline.key)
        .toSet();

    if (disciplineKeys.isEmpty) {
      return _lastActivityForType(typeKey)?.currentLesson ?? 0;
    }

    var progress = 0;

    for (final disciplineKey in disciplineKeys) {
      final last = _lastActivityForDiscipline(disciplineKey);
      if (last != null && last.currentLesson > progress) {
        progress = last.currentLesson;
      }
    }

    return progress;
  }

  List<StudyActivity> _filteredActivities() {
    final now = DateTime.now();

    Iterable<StudyActivity> result = _activities;

    if (_selectedStudyTypeKey != null) {
      result = result.where(
        (activity) => activity.studyTypeKey == _selectedStudyTypeKey,
      );
    }

    if (_selectedDisciplineKey != null) {
      result = result.where(
        (activity) =>
            activity.studyDisciplineKey == _selectedDisciplineKey,
      );
    }

    switch (_sessionFilter) {
      case SessionFilter.week:
        final startOfWeek = now.subtract(
          Duration(days: now.weekday - 1),
        );

        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        final end = start.add(const Duration(days: 7));

        result = result.where((activity) {
          final date = activity.datetime;
          return !date.isBefore(start) && date.isBefore(end);
        });
        break;

      case SessionFilter.month:
        result = result.where((activity) {
          final date = activity.datetime;

          return date.year == _selectedYear &&
              date.month == _selectedMonth;
        });
        break;

      case SessionFilter.year:
        result = result.where(
          (activity) => activity.datetime.year == _selectedYear,
        );
        break;

      case SessionFilter.all:
        break;
    }

    return result.toList();
  }

  List<int> get _availableYears {
    final years = _activities.map((activity) => activity.datetime.year).toSet();

    years.add(DateTime.now().year);
    years.add(_selectedYear);

    final result = years.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  Map<String, List<StudyActivity>> _groupActivitiesByDate(
    List<StudyActivity> activities,
  ) {
    final result = <String, List<StudyActivity>>{};

    for (final activity in activities) {
      final label = DateFormat(
        'dd/MM/yyyy EEEE',
        'pt_BR',
      ).format(activity.datetime);

      result.putIfAbsent(label, () => []).add(activity);
    }

    return result;
  }

  String _filterLabel(SessionFilter filter) {
    switch (filter) {
      case SessionFilter.all:
        return 'Tudo';
      case SessionFilter.week:
        return 'Semana';
      case SessionFilter.month:
        return 'Mês';
      case SessionFilter.year:
        return 'Ano';
    }
  }

  String _periodLabel() {
    final now = DateTime.now();

    switch (_sessionFilter) {
      case SessionFilter.all:
        return 'Todo o histórico';

      case SessionFilter.week:
        final start = now.subtract(
          Duration(days: now.weekday - 1),
        );
        final end = start.add(const Duration(days: 6));

        return '${DateFormat('dd/MM').format(start)} – '
            '${DateFormat('dd/MM').format(end)}';

      case SessionFilter.month:
        final month = _monthFormatter.format(
          DateTime(_selectedYear, _selectedMonth),
        );

        return '${month[0].toUpperCase()}${month.substring(1)}/$_selectedYear';

      case SessionFilter.year:
        return '$_selectedYear';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Persistência
  // ═══════════════════════════════════════════════════════════════════════

  Future<dynamic> _saveType(StudyType type) async {
    if (type.key != null) {
      await _typesBox.put(type.key, type.toHive());
      return type.key;
    }

    return _typesBox.add(type.toHive());
  }

  Future<dynamic> _saveDiscipline(StudyDiscipline discipline) async {
    if (discipline.key != null) {
      await _disciplinesBox.put(
        discipline.key,
        discipline.toHive(),
      );

      return discipline.key;
    }

    return _disciplinesBox.add(discipline.toHive());
  }

  Future<void> _deleteType(StudyType type) async {
    final activityKeys = _activitiesBox.keys.where((key) {
      final activity = StudyActivity.fromHive(
        key,
        _activitiesBox.get(key),
      );

      return activity.studyTypeKey == type.key;
    }).toList();

    for (final key in activityKeys) {
      await _activitiesBox.delete(key);
    }

    final scheduleKeys = _schedulesBox.keys.where((key) {
      final schedule = StudySchedule.fromHive(
        key,
        _schedulesBox.get(key),
      );

      return schedule.studyTypeKey == type.key;
    }).toList();

    for (final key in scheduleKeys) {
      await _schedulesBox.delete(key);
    }

    final disciplineKeys = _disciplinesBox.keys.where((key) {
      final discipline = StudyDiscipline.fromHive(
        key,
        _disciplinesBox.get(key),
      );

      return discipline.studyTypeKey == type.key;
    }).toList();

    for (final key in disciplineKeys) {
      await _disciplinesBox.delete(key);
    }

    await _typesBox.delete(type.key);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveActivity(StudyActivity activity) async {
    if (activity.key != null) {
      await _activitiesBox.put(
        activity.key,
        activity.toHive(),
      );
    } else {
      await _activitiesBox.add(activity.toHive());
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteActivity(dynamic key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remover sessão?'),
          content: const Text('Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _activitiesBox.delete(key);

    if (!mounted) return;

    // Confirma se o registro realmente saiu do box
    if (_activitiesBox.get(key) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover a sessão.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão removida.')),
    );
  }

  Future<void> _toggleActivityDone(dynamic key) async {
    final raw = _activitiesBox.get(key);
    if (raw == null) return;

    final activity = StudyActivity.fromHive(key, raw);
    activity.isDone = !activity.isDone;

    await _activitiesBox.put(
      key,
      activity.toHive(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveSchedule(StudySchedule schedule) async {
    if (schedule.key != null) {
      await _schedulesBox.put(
        schedule.key,
        schedule.toHive(),
      );
    } else {
      await _schedulesBox.add(schedule.toHive());
    }

    await NotificationService.rescheduleStudyNotifications();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSchedule(dynamic key) async {
    await _schedulesBox.delete(key);
    await NotificationService.rescheduleStudyNotifications();

    if (!mounted) return;
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Modais
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _showStudyTypeForm({
    StudyType? existing,
  }) async {
    await showDialog(
      context: context,
      builder: (_) {
        return _StudyTypeForm(
          existing: existing,
          disciplinesBox: _disciplinesBox,
          onSaveType: _saveType,
          onSaveDiscipline: _saveDiscipline,
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showActivityForm({
    StudyActivity? existing,
    dynamic preselectedTypeKey,
  }) async {
    if (_typesBox.isEmpty) {
      await _showStudyTypeForm();

      if (_typesBox.isEmpty) return;
    }

    await showDialog(
      context: context,
      builder: (_) {
        return _StudyActivityForm(
          existing: existing,
          preselectedTypeKey: preselectedTypeKey,
          types: _studyTypes,
          disciplines: _disciplines,
          onSaveType: (type) async {
            final key = await _saveType(type);

            if (mounted) {
              setState(() {});
            }

            return key;
          },
          onSaveActivity: _saveActivity,
          onSaveSchedule: _saveSchedule,
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showScheduleForm({
    StudySchedule? existing,
  }) async {
    if (_typesBox.isEmpty) {
      await _showStudyTypeForm();

      if (_typesBox.isEmpty) return;
    }

    await showDialog(
      context: context,
      builder: (_) {
        return _StudyScheduleForm(
          existing: existing,
          types: _studyTypes,
          disciplines: _disciplines,
          onSave: _saveSchedule,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Aba Cursos
  // ═══════════════════════════════════════════════════════════════════════

  Widget _coursesTab() {
    return ValueListenableBuilder(
      valueListenable: _typesBox.listenable(),
      builder: (_, __, ___) {
        final types = _studyTypes;

        if (types.isEmpty) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: _showStudyTypeForm,
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar curso'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: types.length,
          itemBuilder: (_, index) {
            final type = types[index];
            final disciplines = _disciplinesForCourse(type.key);

            final last = _lastActivityForType(type.key);
            final current = _progressForType(type.key);

            final total = disciplines.isEmpty
                ? type.totalLessons
                : disciplines.fold(
                    0,
                    (sum, discipline) => sum + discipline.totalLessons,
                  );

            final percent = total <= 0
                ? 0.0
                : ((current / total) * 100).clamp(0, 100).toDouble();

            final finished = current >= total && total > 0;

            return _CourseCard(
              type: type,
              disciplinesCount: disciplines.length,
              currentLesson: current,
              totalLessons: total,
              percent: percent,
              finished: finished,
              lastUpdated: last != null
                  ? _fmtDateTime(last.datetimeMillis)
                  : '—',
              totalMinutes: _totalMinutesForType(type.key),
              onEdit: () => _showStudyTypeForm(
                existing: type.copy(),
              ),
              onDelete: () => _confirmDeleteType(type),
              onTap: () => _showCourseDetail(type),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteType(StudyType type) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Remover "${type.name}"?'),
          content: const Text(
            'Isso removerá as disciplinas, sessões e agendamentos relacionados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await _deleteType(type);

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  void _showCourseDetail(StudyType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return ValueListenableBuilder(
              valueListenable: _activitiesBox.listenable(),
              builder: (_, __, ___) {
                final disciplines = _disciplinesForCourse(type.key);
                final activities = _activities
                    .where(
                      (activity) => activity.studyTypeKey == type.key,
                    )
                    .toList();

                return SafeArea(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        type.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (type.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            type.description,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (disciplines.isNotEmpty) ...[
                        const Text(
                          'Disciplinas',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...disciplines.map(
                          (discipline) => _DisciplineProgressTile(
                            discipline: discipline,
                            currentLesson: _lastActivityForDiscipline(
                                      discipline.key,
                                    )
                                    ?.currentLesson ??
                                0,
                            totalMinutes: _totalMinutesForDiscipline(
                              discipline.key,
                            ),
                            lastUpdated: _lastActivityForDiscipline(
                                      discipline.key,
                                    ) !=
                                    null
                                ? _fmtDateTime(
                                    _lastActivityForDiscipline(
                                      discipline.key,
                                    )!.datetimeMillis,
                                  )
                                : '—',
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showActivityForm(
                              preselectedTypeKey: type.key,
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar nova sessão'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Histórico de sessões',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (activities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text('Nenhuma sessão registrada.'),
                          ),
                        )
                      else
                        ...activities.map(
                          (activity) => _SessionTile(
                            activity: activity,
                            dateLabel: _fmtDateTime(
                              activity.datetimeMillis,
                            ),
                            onToggleDone: () => _toggleActivityDone(
                              activity.key,
                            ),
                            onEdit: () {
                              Navigator.pop(sheetContext);
                              _showActivityForm(
                                existing: activity.copy(),
                              );
                            },
                            onDelete: () => _deleteActivity(
                              activity.key,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Aba Sessões
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFilterChip(SessionFilter filter) {
    return ChoiceChip(
      label: Text(_filterLabel(filter)),
      selected: _sessionFilter == filter,
      selectedColor: Colors.deepPurple.shade100,
      onSelected: (selected) {
        if (!selected) return;

        setState(() {
          _sessionFilter = filter;

          if (filter == SessionFilter.month) {
            _selectedMonth = DateTime.now().month;
            _selectedYear = DateTime.now().year;
          }

          if (filter == SessionFilter.year) {
            _selectedYear = DateTime.now().year;
          }
        });
      },
    );
  }

  Widget _buildPeriodSelectors() {
    if (_sessionFilter == SessionFilter.all ||
        _sessionFilter == SessionFilter.week) {
      return const SizedBox.shrink();
    }

    if (_sessionFilter == SessionFilter.year) {
      return Row(
        children: [
          const Text('Ano:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            items: _availableYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
              }
            },
          ),
        ],
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        const Text('Mês:'),
        DropdownButton<int>(
          value: _selectedMonth,
          items: List.generate(12, (index) {
            final month = index + 1;
            final label = _monthFormatter.format(
              DateTime(_selectedYear, month),
            );

            return DropdownMenuItem(
              value: month,
              child: Text(
                '${label[0].toUpperCase()}${label.substring(1)}',
              ),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedMonth = value);
            }
          },
        ),
        const Text('Ano:'),
        DropdownButton<int>(
          value: _selectedYear,
          items: _availableYears
              .map(
                (year) => DropdownMenuItem(
                  value: year,
                  child: Text('$year'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedYear = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCourseSelector() {
    final types = _studyTypes;

    if (_selectedStudyTypeKey != null &&
        !types.any((type) => type.key == _selectedStudyTypeKey)) {
      _selectedStudyTypeKey = null;
      _selectedDisciplineKey = null;
    }

    return DropdownButtonFormField<dynamic>(
      value: _selectedStudyTypeKey,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Curso',
        prefixIcon: Icon(Icons.school_outlined),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<dynamic>(
          value: null,
          child: Text('Todos os cursos'),
        ),
        ...types.map(
          (type) => DropdownMenuItem<dynamic>(
            value: type.key,
            child: Text(
              type.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedStudyTypeKey = value;
          _selectedDisciplineKey = null;
        });
      },
    );
  }

  Widget _buildDisciplineFilter() {
    if (_selectedStudyTypeKey == null) {
      _selectedDisciplineKey = null;
      return const SizedBox.shrink();
    }

    final disciplines = _disciplinesForCourse(
      _selectedStudyTypeKey,
    );

    if (disciplines.isEmpty) {
      _selectedDisciplineKey = null;
      return const SizedBox.shrink();
    }

    if (_selectedDisciplineKey != null &&
        !disciplines.any(
          (discipline) => discipline.key == _selectedDisciplineKey,
        )) {
      _selectedDisciplineKey = null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<dynamic>(
        value: _selectedDisciplineKey,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Disciplina',
          prefixIcon: Icon(Icons.menu_book_outlined),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<dynamic>(
            value: null,
            child: Text('Todas as disciplinas'),
          ),
          ...disciplines.map(
            (discipline) => DropdownMenuItem<dynamic>(
              value: discipline.key,
              child: Text(
                discipline.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() => _selectedDisciplineKey = value);
        },
      ),
    );
  }

  Widget _sessionsTab() {
    return ValueListenableBuilder(
      valueListenable: _activitiesBox.listenable(),
      builder: (_, __, ___) {
        final activities = _filteredActivities();

        Iterable<StudySchedule> schedules = _schedules;

        if (_selectedStudyTypeKey != null) {
          schedules = schedules.where(
            (schedule) =>
                schedule.studyTypeKey == _selectedStudyTypeKey,
          );
        }

        if (_selectedDisciplineKey != null) {
          schedules = schedules.where(
            (schedule) =>
                schedule.studyDisciplineKey == _selectedDisciplineKey,
          );
        }

        final scheduleList = schedules.toList();
        final grouped = _groupActivitiesByDate(activities);
        final totalMinutes = activities.fold<int>(
          0,
          (sum, activity) => sum + activity.durationMinutes,
        );
        final doneCount = activities.where((a) => a.isDone).length;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (scheduleList.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sessões agendadas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showScheduleForm,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo'),
                  ),
                ],
              ),
              ...scheduleList.map(
                (schedule) => _ScheduleTile(
                  schedule: schedule,
                  courseName: _typeByKey(
                            schedule.studyTypeKey,
                          )
                          ?.name ??
                      'Curso removido',
                  disciplineName: _disciplineByKey(
                    schedule.studyDisciplineKey,
                  )?.name,
                  weekdayNames: _weekdayNames,
                  onToggle: () async {
                    final raw = _schedulesBox.get(schedule.key);
                    if (raw == null) return;

                    final updated = StudySchedule.fromHive(
                      schedule.key,
                      raw,
                    );

                    updated.isActive = !updated.isActive;
                    await _saveSchedule(updated);
                  },
                  onEdit: () => _showScheduleForm(
                    existing: schedule.copy(),
                  ),
                  onDelete: () => _deleteSchedule(schedule.key),
                ),
              ),
              const Divider(height: 32),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _periodLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip(SessionFilter.all),
                _buildFilterChip(SessionFilter.week),
                _buildFilterChip(SessionFilter.month),
                _buildFilterChip(SessionFilter.year),
              ],
            ),
            const SizedBox(height: 8),
            _buildPeriodSelectors(),
            const SizedBox(height: 12),
            _buildCourseSelector(),
            _buildDisciplineFilter(),
            const SizedBox(height: 12),
            if (activities.isNotEmpty)
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.history,
                          value: '${activities.length}',
                          label: 'Sessões',
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.check_circle,
                          value: '$doneCount',
                          label: 'Concluídas',
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.timer,
                          value:
                              '${totalMinutes ~/ 60}h ${totalMinutes % 60}min',
                          label: 'Estudados',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Nenhuma sessão neste período.'),
                ),
              )
            else
              ...grouped.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        bottom: 4,
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (activity) => _SessionTile(
                        activity: activity,
                        dateLabel: _fmtDateTime(
                          activity.datetimeMillis,
                        ),
                        onToggleDone: () => _toggleActivityDone(
                          activity.key,
                        ),
                        onEdit: () => _showActivityForm(
                          existing: activity.copy(),
                        ),
                        onDelete: () => _deleteActivity(
                          activity.key,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Aba Resumo
  // ═══════════════════════════════════════════════════════════════════════

  Widget _summaryTab() {
    return ValueListenableBuilder(
      valueListenable: _typesBox.listenable(),
      builder: (_, __, ___) {
        final types = _studyTypes;

        if (types.isEmpty) {
          return const Center(
            child: Text('Nenhum curso cadastrado.'),
          );
        }

        final totalMinutes = _activities.fold<int>(
          0,
          (sum, activity) => sum + activity.durationMinutes,
        );

        final completed = types.where((type) {
          final disciplines = _disciplinesForCourse(type.key);

          if (disciplines.isEmpty) {
            final last = _lastActivityForType(type.key);

            return last != null &&
                last.currentLesson >= type.totalLessons &&
                type.totalLessons > 0;
          }

          return disciplines.every((discipline) {
            final last = _lastActivityForDiscipline(
              discipline.key,
            );

            return last != null &&
                last.currentLesson >= discipline.totalLessons &&
                discipline.totalLessons > 0;
          });
        }).length;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                _StatCard(
                  label: 'Cursos',
                  value: '${types.length}',
                  icon: Icons.school,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: 'Sessões',
                  value: '${_activities.length}',
                  icon: Icons.history,
                  color: Colors.purple,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: 'Concluídos',
                  value: '$completed',
                  icon: Icons.emoji_events,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 32,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tempo total estudado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${totalMinutes ~/ 60}h ${totalMinutes % 60}min',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Progresso por curso',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...types.map(
              (type) {
                final disciplines = _disciplinesForCourse(type.key);

                if (disciplines.isEmpty) {
                  final last = _lastActivityForType(type.key);
                  final current = last?.currentLesson ?? 0;
                  final total = type.totalLessons;

                  return _ProgressCard(
                    title: type.name,
                    currentLesson: current,
                    totalLessons: total,
                    totalMinutes: _totalMinutesForType(type.key),
                    lastUpdated: last != null
                        ? _fmtDateTime(last.datetimeMillis)
                        : '—',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        bottom: 4,
                      ),
                      child: Text(
                        type.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...disciplines.map(
                      (discipline) {
                        final last = _lastActivityForDiscipline(
                          discipline.key,
                        );

                        return _ProgressCard(
                          title: discipline.name,
                          currentLesson: last?.currentLesson ?? 0,
                          totalLessons: discipline.totalLessons,
                          totalMinutes: _totalMinutesForDiscipline(
                            discipline.key,
                          ),
                          lastUpdated: last != null
                              ? _fmtDateTime(last.datetimeMillis)
                              : '—',
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Cursos',
              icon: Icon(Icons.school),
            ),
            Tab(
              text: 'Sessões',
              icon: Icon(Icons.history),
            ),
            Tab(
              text: 'Resumo',
              icon: Icon(Icons.show_chart),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _coursesTab(),
          _sessionsTab(),
          _summaryTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          switch (_tabController.index) {
            case 0:
              return FloatingActionButton(
                onPressed: _showStudyTypeForm,
                tooltip: 'Novo curso',
                child: const Icon(Icons.school),
              );

            case 1:
              return FloatingActionButton(
                onPressed: _showActivityForm,
                tooltip: 'Registrar sessão',
                child: const Icon(Icons.add),
              );

            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Formulário de curso e disciplinas
// ═══════════════════════════════════════════════════════════════════════════

class _DisciplineDraft {
  dynamic key;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController lessonsController;

  _DisciplineDraft({
    this.key,
    String name = '',
    String description = '',
    String totalLessons = '',
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description),
        lessonsController = TextEditingController(text: totalLessons);

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    lessonsController.dispose();
  }
}

class _StudyTypeForm extends StatefulWidget {
  final StudyType? existing;
  final Box disciplinesBox;
  final Future<dynamic> Function(StudyType type) onSaveType;
  final Future<dynamic> Function(StudyDiscipline discipline)
      onSaveDiscipline;

  const _StudyTypeForm({
    Key? key,
    this.existing,
    required this.disciplinesBox,
    required this.onSaveType,
    required this.onSaveDiscipline,
  }) : super(key: key);

  @override
  State<_StudyTypeForm> createState() => _StudyTypeFormState();
}

class _StudyTypeFormState extends State<_StudyTypeForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _lessonsController;
  late final TextEditingController _categoryController;

  final List<_DisciplineDraft> _drafts = [];
  bool _hasDisciplines = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _nameController = TextEditingController(
      text: existing?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _lessonsController = TextEditingController(
      text: existing?.totalLessons.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: existing?.category ?? '',
    );

    if (existing != null) {
      final disciplines = widget.disciplinesBox.keys
          .map(
            (key) => StudyDiscipline.fromHive(
              key,
              widget.disciplinesBox.get(key),
            ),
          )
          .where(
            (discipline) => discipline.studyTypeKey == existing.key,
          )
          .toList();

      _hasDisciplines = disciplines.isNotEmpty;

      for (final discipline in disciplines) {
        _drafts.add(
          _DisciplineDraft(
            key: discipline.key,
            name: discipline.name,
            description: discipline.description,
            totalLessons: discipline.totalLessons.toString(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _lessonsController.dispose();
    _categoryController.dispose();

    for (final draft in _drafts) {
      draft.dispose();
    }

    super.dispose();
  }

  void _addDraft() {
    setState(() {
      _drafts.insert(0, _DisciplineDraft());
    });
  }

  void _removeDraft(int index) {
    final draft = _drafts.removeAt(index);
    draft.dispose();

    setState(() {});
  }

  Future<void> _saveAllDisciplines(dynamic courseKey) async {
    final previousKeys = widget.disciplinesBox.keys.where((key) {
      final discipline = StudyDiscipline.fromHive(
        key,
        widget.disciplinesBox.get(key),
      );

      return discipline.studyTypeKey == courseKey;
    }).toList();

    final savedKeys = <dynamic>{};

    for (final draft in _drafts) {
      final name = draft.nameController.text.trim();
      final description = draft.descriptionController.text.trim();
      final totalLessons = int.tryParse(
        draft.lessonsController.text.trim(),
      );

      if (name.isEmpty || totalLessons == null || totalLessons <= 0) {
        continue;
      }

      final discipline = StudyDiscipline(
        key: draft.key,
        studyTypeKey: courseKey,
        name: name,
        description: description,
        totalLessons: totalLessons,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final key = await widget.onSaveDiscipline(discipline);
      savedKeys.add(key);
    }

    for (final key in previousKeys) {
      if (!savedKeys.contains(key)) {
        await widget.disciplinesBox.delete(key);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_hasDisciplines && _drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos uma disciplina.'),
        ),
      );
      return;
    }

    final type = StudyType(
      key: widget.existing?.key,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      totalLessons: int.parse(_lessonsController.text.trim()),
      category: _categoryController.text.trim(),
      createdAt: widget.existing?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
    );

    final courseKey = await widget.onSaveType(type);

    if (_hasDisciplines) {
      await _saveAllDisciplines(courseKey);
    } else {
      final previousKeys = widget.disciplinesBox.keys.where((key) {
        final discipline = StudyDiscipline.fromHive(
          key,
          widget.disciplinesBox.get(key),
        );

        return discipline.studyTypeKey == courseKey;
      }).toList();

      for (final key in previousKeys) {
        await widget.disciplinesBox.delete(key);
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Cadastrar curso'
            : 'Editar curso',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do curso',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do curso';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lessonsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total geral de aulas',
                ),
                validator: (value) {
                  final total = int.tryParse(value?.trim() ?? '');

                  if (total == null || total <= 0) {
                    return 'Informe um total válido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Este curso possui disciplinas'),
                subtitle: const Text(
                  'Cada disciplina terá seu próprio progresso',
                ),
                value: _hasDisciplines,
                onChanged: (value) {
                  setState(() {
                    _hasDisciplines = value;

                    if (value && _drafts.isEmpty) {
                      _drafts.add(_DisciplineDraft());
                    }
                  });
                },
              ),
              if (_hasDisciplines) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Disciplinas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _addDraft,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                ...List.generate(
                  _drafts.length,
                  (index) {
                    final draft = _drafts[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: draft.nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome da disciplina',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _removeDraft(index),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            TextField(
                              controller: draft.lessonsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Total de aulas',
                              ),
                            ),
                            TextField(
                              controller: draft.descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Descrição opcional',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Formulário de sessão
// ═══════════════════════════════════════════════════════════════════════════



class _StudyActivityForm extends StatefulWidget {
  final StudyActivity? existing;
  final dynamic preselectedTypeKey;
  final List<StudyType> types;
  final List<StudyDiscipline> disciplines;
  final Future<dynamic> Function(StudyType type) onSaveType;
  final Future<void> Function(StudyActivity activity) onSaveActivity;
  final Future<void> Function(StudySchedule schedule) onSaveSchedule;

  const _StudyActivityForm({
    Key? key,
    this.existing,
    this.preselectedTypeKey,
    required this.types,
    required this.disciplines,
    required this.onSaveType,
    required this.onSaveActivity,
    required this.onSaveSchedule,
  }) : super(key: key);

  @override
  State<_StudyActivityForm> createState() => _StudyActivityFormState();
}

class _StudyActivityFormState extends State<_StudyActivityForm> {
  final _formKey = GlobalKey<FormState>();

  late dynamic _selectedTypeKey;
  dynamic _selectedDisciplineKey;

  late final TextEditingController _lessonController;
  late final TextEditingController _durationController;
  late final TextEditingController _notesController;
  late final TextEditingController _revisionCountController;

  late DateTime _chosenDate;

  bool _isRecurring = false;
  final List<int> _selectedWeekdays = [];
  TimeOfDay _selectedTime = const TimeOfDay(
    hour: 19,
    minute: 0,
  );

  bool get _isEdit => widget.existing != null;

  List<StudyDiscipline> get _availableDisciplines {
    return widget.disciplines
        .where(
          (discipline) =>
              discipline.studyTypeKey == _selectedTypeKey,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    _selectedTypeKey = widget.existing?.studyTypeKey ??
        widget.preselectedTypeKey ??
        widget.types.first.key;

    _selectedDisciplineKey = widget.existing?.studyDisciplineKey;

    _lessonController = TextEditingController(
      text: widget.existing?.currentLesson.toString() ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existing?.durationMinutes.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _revisionCountController = TextEditingController(
      text: widget.existing?.revisionCount.toString() ?? '0',
    );

    _chosenDate = widget.existing?.datetime ?? DateTime.now();
  }

  @override
  void dispose() {
    _lessonController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _revisionCountController.dispose();
    super.dispose();
  }

  void _changeType(dynamic value) {
    setState(() {
      _selectedTypeKey = value;

      final exists = _availableDisciplines.any(
        (discipline) => discipline.key == _selectedDisciplineKey,
      );

      if (!exists) {
        _selectedDisciplineKey = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_isRecurring) {
      if (_selectedWeekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione ao menos um dia da semana.'),
          ),
        );
        return;
      }

      await widget.onSaveSchedule(
        StudySchedule(
          studyTypeKey: _selectedTypeKey,
          studyDisciplineKey: _selectedDisciplineKey,
          weekdays: List<int>.from(_selectedWeekdays),
          timeHour: _selectedTime.hour,
          timeMinute: _selectedTime.minute,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      if (mounted) Navigator.pop(context);
      return;
    }

    if (!_isRecurring &&
        _availableDisciplines.isNotEmpty &&
        _selectedDisciplineKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione uma disciplina antes de registrar a sessão.',
          ),
        ),
      );

      return;
    }

    if (!_formKey.currentState!.validate()) return;

    await widget.onSaveActivity(
      StudyActivity(
        key: widget.existing?.key,
        studyTypeKey: _selectedTypeKey,
        studyDisciplineKey: _selectedDisciplineKey,
        currentLesson: int.parse(
          _lessonController.text.trim(),
        ),
        durationMinutes: int.tryParse(
              _durationController.text.trim(),
            ) ??
            0,
        notes: _notesController.text.trim(),
        datetimeMillis: _chosenDate.millisecondsSinceEpoch,
        isDone: widget.existing?.isDone ?? false,
        revisionCount: int.parse(
          _revisionCountController.text.trim(),
        ),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _openFocusMode() async {
    final availableDisciplines = _availableDisciplines;

    if (availableDisciplines.isNotEmpty && _selectedDisciplineKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione uma disciplina antes de abrir o modo foco.',
          ),
        ),
      );

      return;
    }

    StudyType? type;

    for (final item in widget.types) {
      if (item.key == _selectedTypeKey) {
        type = item;
        break;
      }
    }

    StudyDiscipline? discipline;

    for (final item in widget.disciplines) {
      if (item.key == _selectedDisciplineKey) {
        discipline = item;
        break;
      }
    }

    final typeName = type?.name ?? 'Sessão de estudos';

    final taskTitle = discipline == null
        ? typeName
        : '$typeName · ${discipline.name}';

    // Abre o modo foco por cima do diálogo e ESPERA o valor voltar.
    final studiedMinutes = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => FocusScreen(taskTitle: taskTitle),
      ),
    );

    // Cancelar → null → não altera nada.
    if (!mounted || studiedMinutes == null) return;

    setState(() {
      _durationController.text = studiedMinutes.toString();
    });
  }

  Future<void> _createNewType() async {
    Navigator.pop(context);

    await showDialog(
      context: context,
      builder: (_) {
        return _StudyTypeForm(
          disciplinesBox: Hive.box('alfred_study_disciplines'),
          onSaveType: widget.onSaveType,
          onSaveDiscipline: (discipline) async {
            final box = Hive.box('alfred_study_disciplines');

            if (discipline.key != null) {
              await box.put(
                discipline.key,
                discipline.toHive(),
              );

              return discipline.key;
            }

            return box.add(discipline.toHive());
          },
        );
      },
    );
  }

  Future<void> _chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _chosenDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_chosenDate),
    );

    if (time == null) return;

    setState(() {
      _chosenDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final disciplines = _availableDisciplines;

    return AlertDialog(
      title: Text(
        _isEdit ? 'Editar sessão' : 'Registrar sessão',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<dynamic>(
                value: _selectedTypeKey,
                isExpanded: true,
                items: widget.types
                    .map(
                      (type) => DropdownMenuItem(
                        value: type.key,
                        child: Text(
                          type.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _changeType,
                decoration: const InputDecoration(
                  labelText: 'Curso',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              if (disciplines.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<dynamic>(
                  value: _selectedDisciplineKey,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<dynamic>(
                      value: null,
                      child: Text('Sem disciplina'),
                    ),
                    ...disciplines.map(
                      (discipline) => DropdownMenuItem(
                        value: discipline.key,
                        child: Text(
                          discipline.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDisciplineKey = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Disciplina',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                ),
              ],
              if (!_isRecurring) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lessonController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aula/matéria atual',
                  ),
                  validator: (value) {
                    final number = int.tryParse(
                      value?.trim() ?? '',
                    );

                    if (number == null || number < 0) {
                      return 'Informe uma aula válida';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duração (minutos)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Anotações',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _revisionCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de revisões',
                    prefixIcon: Icon(Icons.replay),
                    helperText: 'Informe quantas vezes esta sessão foi revisada',
                  ),
                  validator: (value) {
                    final number = int.tryParse(
                      value?.trim() ?? '',
                    );

                    if (number == null || number < 0) {
                      return 'Informe zero ou um número positivo';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Data e hora: '
                        '${DateFormat('dd/MM/yyyy HH:mm').format(_chosenDate)}',
                      ),
                    ),
                    TextButton(
                      onPressed: _chooseDateTime,
                      child: const Text('Escolher'),
                    ),
                  ],
                ),
              ],
              if (!_isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isRecurring,
                  title: const Text('Programar sessão recorrente'),
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                    });
                  },
                ),
              ],
              if (_isRecurring) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dias da semana',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [1, 2, 3, 4, 5, 6, 7].map(
                    (weekday) {
                      return FilterChip(
                        label: Text(
                          const {
                            1: 'Seg',
                            2: 'Ter',
                            3: 'Qua',
                            4: 'Qui',
                            5: 'Sex',
                            6: 'Sáb',
                            7: 'Dom',
                          }[weekday]!,
                        ),
                        selected: _selectedWeekdays.contains(weekday),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedWeekdays.add(weekday);
                            } else {
                              _selectedWeekdays.remove(weekday);
                            }
                          });
                        },
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Horário da sessão'),
                  subtitle: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );

                    if (time != null) {
                      setState(() {
                        _selectedTime = time;
                      });
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (!_isEdit && !_isRecurring)
          TextButton.icon(
            onPressed: _openFocusMode,
            icon: const Icon(
              Icons.center_focus_strong,
              size: 18,
            ),
            label: const Text('Modo foco'),
          ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            _isRecurring
                ? 'Salvar agendamento'
                : (_isEdit ? 'Salvar' : 'Registrar'),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Formulário de agendamento
// ═══════════════════════════════════════════════════════════════════════════

class _StudyScheduleForm extends StatefulWidget {
  final StudySchedule? existing;
  final List<StudyType> types;
  final List<StudyDiscipline> disciplines;
  final Future<void> Function(StudySchedule schedule) onSave;

  const _StudyScheduleForm({
    Key? key,
    this.existing,
    required this.types,
    required this.disciplines,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_StudyScheduleForm> createState() => _StudyScheduleFormState();
}

class _StudyScheduleFormState extends State<_StudyScheduleForm> {
  late dynamic _selectedTypeKey;
  dynamic _selectedDisciplineKey;
  late TimeOfDay _selectedTime;

  final List<int> _selectedWeekdays = [];

  List<StudyDiscipline> get _availableDisciplines {
    return widget.disciplines
        .where(
          (discipline) =>
              discipline.studyTypeKey == _selectedTypeKey,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    _selectedTypeKey = widget.existing?.studyTypeKey ??
        widget.types.first.key;

    _selectedDisciplineKey = widget.existing?.studyDisciplineKey;

    _selectedWeekdays.addAll(
      widget.existing?.weekdays ?? [],
    );

    _selectedTime = TimeOfDay(
      hour: widget.existing?.timeHour ?? 19,
      minute: widget.existing?.timeMinute ?? 0,
    );
  }

  void _changeType(dynamic value) {
    setState(() {
      _selectedTypeKey = value;

      final valid = _availableDisciplines.any(
        (discipline) => discipline.key == _selectedDisciplineKey,
      );

      if (!valid) {
        _selectedDisciplineKey = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos um dia da semana.'),
        ),
      );
      return;
    }

    await widget.onSave(
      StudySchedule(
        key: widget.existing?.key,
        studyTypeKey: _selectedTypeKey,
        studyDisciplineKey: _selectedDisciplineKey,
        weekdays: List<int>.from(_selectedWeekdays),
        timeHour: _selectedTime.hour,
        timeMinute: _selectedTime.minute,
        createdAt: widget.existing?.createdAt ??
            DateTime.now().millisecondsSinceEpoch,
        isActive: widget.existing?.isActive ?? true,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final disciplines = _availableDisciplines;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Novo agendamento'
            : 'Editar agendamento',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<dynamic>(
              value: _selectedTypeKey,
              isExpanded: true,
              items: widget.types
                  .map(
                    (type) => DropdownMenuItem(
                      value: type.key,
                      child: Text(
                        type.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _changeType,
              decoration: const InputDecoration(
                labelText: 'Curso',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            if (disciplines.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<dynamic>(
                value: _selectedDisciplineKey,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<dynamic>(
                    value: null,
                    child: Text('Sem disciplina'),
                  ),
                  ...disciplines.map(
                    (discipline) => DropdownMenuItem(
                      value: discipline.key,
                      child: Text(
                        discipline.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDisciplineKey = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dias da semana',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [1, 2, 3, 4, 5, 6, 7].map(
                (weekday) {
                  const labels = {
                    1: 'Seg',
                    2: 'Ter',
                    3: 'Qua',
                    4: 'Qui',
                    5: 'Sex',
                    6: 'Sáb',
                    7: 'Dom',
                  };

                  return FilterChip(
                    label: Text(labels[weekday]!),
                    selected: _selectedWeekdays.contains(weekday),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedWeekdays.add(weekday);
                        } else {
                          _selectedWeekdays.remove(weekday);
                        }
                      });
                    },
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Horário'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );

                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets visuais
// ═══════════════════════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final StudyType type;
  final int disciplinesCount;
  final int currentLesson;
  final int totalLessons;
  final double percent;
  final bool finished;
  final String lastUpdated;
  final int totalMinutes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _CourseCard({
    required this.type,
    required this.disciplinesCount,
    required this.currentLesson,
    required this.totalLessons,
    required this.percent,
    required this.finished,
    required this.lastUpdated,
    required this.totalMinutes,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      type.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (type.category.isNotEmpty)
                    Text(
                      type.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                ],
              ),
              if (type.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    type.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (disciplinesCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$disciplinesCount disciplina(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: totalLessons > 0
                    ? (currentLesson / totalLessons).clamp(0.0, 1.0)
                    : 0,
                color: finished ? Colors.green : null,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aula $currentLesson / $totalLessons '
                    '(${percent.toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    finished ? 'Concluído' : 'Em progresso',
                    style: TextStyle(
                      fontSize: 12,
                      color: finished ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Última sessão: $lastUpdated',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '$totalMinutes min estudados',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisciplineProgressTile extends StatelessWidget {
  final StudyDiscipline discipline;
  final int currentLesson;
  final int totalMinutes;
  final String lastUpdated;

  const _DisciplineProgressTile({
    required this.discipline,
    required this.currentLesson,
    required this.totalMinutes,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final total = discipline.totalLessons;
    final progress = total <= 0
        ? 0.0
        : (currentLesson / total).clamp(0.0, 1.0);

    final finished = total > 0 && currentLesson >= total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              discipline.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (discipline.description.isNotEmpty)
              Text(
                discipline.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: finished ? Colors.green : null,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aula $currentLesson / $total',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '$totalMinutes min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Text(
              'Última sessão: $lastUpdated',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final int currentLesson;
  final int totalLessons;
  final int totalMinutes;
  final String lastUpdated;

  const _ProgressCard({
    required this.title,
    required this.currentLesson,
    required this.totalLessons,
    required this.totalMinutes,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalLessons <= 0
        ? 0.0
        : (currentLesson / totalLessons).clamp(0.0, 1.0);

    final finished = totalLessons > 0 && currentLesson >= totalLessons;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  finished ? 'Concluído' : 'Em progresso',
                  style: TextStyle(
                    fontSize: 11,
                    color: finished ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: finished ? Colors.green : null,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aula $currentLesson / $totalLessons',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '$totalMinutes min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Text(
              'Última sessão: $lastUpdated',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.deepPurple,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final StudyActivity activity;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String dateLabel;

  const _SessionTile({
    required this.activity,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final typeRaw = Hive.box('alfred_study_types').get(
      activity.studyTypeKey,
    );

    final typeName = typeRaw == null
        ? 'Curso removido'
        : StudyType.fromHive(
            activity.studyTypeKey,
            typeRaw,
          ).name;

    String? disciplineName;

    if (activity.studyDisciplineKey != null) {
      final disciplineRaw = Hive.box(
        'alfred_study_disciplines',
      ).get(activity.studyDisciplineKey);

      if (disciplineRaw != null) {
        disciplineName = StudyDiscipline.fromHive(
          activity.studyDisciplineKey,
          disciplineRaw,
        ).name;
      }
    }

    final titlePrefix = disciplineName == null
        ? typeName
        : '$typeName · $disciplineName';

    final duration = activity.durationMinutes > 0
        ? ' · ${activity.durationMinutes}min'
        : '';

    return ListTile(
      leading: GestureDetector(
        onTap: onToggleDone,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activity.isDone
                ? Colors.green
                : Colors.blue.shade100,
          ),
          child: Icon(
            activity.isDone ? Icons.check : Icons.school,
            color: activity.isDone ? Colors.white : Colors.blue,
            size: 18,
          ),
        ),
      ),
      title: Text(
        '$titlePrefix — Aula ${activity.currentLesson}$duration',
        style: TextStyle(
          decoration: activity.isDone
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.notes.isNotEmpty)
            Text(
              activity.notes,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (activity.revisionCount > 0)
            Row(
              children: [
                const Icon(
                  Icons.replay,
                  size: 14,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 4),
                Text(
                  activity.revisionCount == 1
                      ? '1 revisão realizada'
                      : '${activity.revisionCount} revisões realizadas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          Text(dateLabel),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 20),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete,
              size: 20,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final StudySchedule schedule;
  final String courseName;
  final String? disciplineName;
  final Map<int, String> weekdayNames;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleTile({
    required this.schedule,
    required this.courseName,
    required this.disciplineName,
    required this.weekdayNames,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = schedule.weekdays
        .map((day) => weekdayNames[day] ?? '$day')
        .join(', ');

    final title = disciplineName == null
        ? courseName
        : '$courseName · $disciplineName';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: schedule.isActive ? null : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(
          Icons.event_repeat,
          color: schedule.isActive
              ? Colors.deepPurple
              : Colors.grey,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$days · ${schedule.timeLabel}'
          '${schedule.isActive ? '' : ' (pausado)'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: schedule.isActive ? 'Pausar' : 'Ativar',
              onPressed: onToggle,
              icon: Icon(
                schedule.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: schedule.isActive
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Remover',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}