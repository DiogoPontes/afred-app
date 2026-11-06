import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// ── Módulos: cores, ícones e helpers compartilhados ──

const Map<String, Color> kModuleColors = {
  'Tarefas': Colors.blueGrey,
  'Finanças': Colors.deepOrange,
  'Atividade Física': Colors.green,
  'Alimentação': Colors.pink,
  'Estudos': Colors.indigo,
  'Leitura': Colors.brown,
  'Compromissos': Colors.teal,
  'Compras': Colors.amber,
};

const Map<String, IconData> kModuleIcons = {
  'Tarefas': Icons.check_circle_outline,
  'Finanças': Icons.payments_outlined,
  'Atividade Física': Icons.fitness_center_outlined,
  'Alimentação': Icons.restaurant_outlined,
  'Estudos': Icons.book_outlined,
  'Leitura': Icons.menu_book_outlined,
  'Compromissos': Icons.calendar_today_outlined,
  'Compras': Icons.shopping_cart_outlined,
};

Color moduleColorOf(String module) => kModuleColors[module] ?? Colors.cyan;

IconData moduleIconOf(String module) =>
    kModuleIcons[module] ?? Icons.category_outlined;

Color priorityColorOf(String priority) {
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

// ── Labels de data (sem depender de locale inicializado) ──

const List<String> kWeekdayNames = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

const List<String> kMonthNames = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String dayLabelOf(DateTime d, {bool showToday = false}) {
  final base =
      '${kWeekdayNames[d.weekday - 1]}, ${d.day} ${kMonthNames[d.month - 1]}';
  return showToday ? '$base • hoje' : base;
}

// ── Formatação ──

String formatBRL(double v) {
  final isNegative = v < 0;
  final s = v.abs().toStringAsFixed(2).replaceAll('.', ',');
  return '${isNegative ? '-' : ''}R\$ $s';
}

String formatHms(int totalSeconds) {
  String two(int v) => v.toString().padLeft(2, '0');

  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  return '${two(h)}:${two(m)}:${two(s)}';
}

String formatReadingDuration(int totalSeconds) {
  if (totalSeconds >= 3600) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  final m = (totalSeconds / 60).round();
  return '$m min';
}

String? formatPace(int durationSeconds, double distanceKm) {
  if (distanceKm <= 0 || durationSeconds <= 0) return null;

  final secPerKm = (durationSeconds / distanceKm).round();
  final m = secPerKm ~/ 60;
  final s = secPerKm % 60;

  return '$m:${s.toString().padLeft(2, '0')}/km';
}

// ── Leitura robusta de campos (aceita variações de nome) ──

DateTime? recordTimestampOf(Map<String, dynamic> item) {
  final ts = item['timestamp'];

  if (ts is String && ts.isNotEmpty) {
    final date = DateTime.tryParse(ts);
    if (date != null) return date;
  }

  final millis = item['datetimeMillis'];
  if (millis is num) {
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt()).toLocal();
  }

  return null;
}

const List<String> _financeAmountKeys = ['value', 'amount', 'valor'];

String? financeAmountKeyOf(Map<String, dynamic> item) {
  for (final key in _financeAmountKeys) {
    if (item[key] is num) return key;
  }
  return null;
}

double? financeAmountOf(Map<String, dynamic> item) {
  for (final key in _financeAmountKeys) {
    final value = item[key];
    if (value is num) return value.toDouble();
  }
  return null;
}

double? activityDistanceKmOf(Map<String, dynamic> item) {
  for (final key in const ['distanceKm', 'distance', 'km']) {
    final value = item[key];
    if (value is num) return value.toDouble();
  }
  return null;
}

String? activityDistanceKeyOf(Map<String, dynamic> item) {
  for (final key in const ['distanceKm', 'distance', 'km']) {
    if (item[key] is num) return key;
  }
  return null;
}

String activityTypeOf(Map<String, dynamic> item) {
  return (item['activityType'] ??
          item['activityName'] ??
          item['type'] ??
          item['exercise'] ??
          'Atividade')
      .toString();
}

/// Duração total do audiobook (segundos). Procura os campos usados pela
/// tela Leitura e, por último, 'pages' dos livros cadastrados pela Home
/// (que guardam minutos para áudio). Null se desconhecida.
int? readingTotalSecondsOf(Map<String, dynamic>? book) {
  if (book == null) return null;

  for (final key in const [
    'totalDurationSeconds',
    'audiobookTotalSeconds',
    'totalSeconds',
  ]) {
    final value = book[key];
    if (value is num && value > 0) return value.toInt();
  }

  final pages = book['pages'];
  if (pages is num && pages > 0) return (pages * 60).toInt();

  return null;
}

bool readingBookIsAudio(Map<String, dynamic>? book) {
  if (book == null) return false;

  if (book['isAudiobook'] == true ||
      book['isAudio'] == true ||
      (book['type']?.toString() ?? '') == 'Áudio') {
    return ((book['audiobookProgressType'] as String?) ?? 'audio') == 'audio';
  }

  return false;
}

// ── Atividade Física: enriquecimento a partir do log real ──
// O resumo em alfred_box carrega um ponteiro (activityLogKey) para o log
// real. Duração/distância podem estar no log com nomes/tipos variados;
// aceitamos número, "00:19:48", "19:48", minutos, etc.

int? _parseFlexibleDuration(dynamic value) {
  if (value is num && value > 0) return value.toInt();
  if (value is! String) return null;

  final text = value.trim();
  if (text.isEmpty) return null;

  if (text.contains(':')) {
    var seconds = 0;

    for (final part in text.split(':')) {
      final parsed = int.tryParse(part.trim());
      if (parsed == null) return null;
      seconds = seconds * 60 + parsed;
    }

    return seconds > 0 ? seconds : null;
  }

  final parsed = int.tryParse(text);
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _parseFlexibleDistance(dynamic value) {
  if (value is num && value > 0) return value.toDouble();
  if (value is! String) return null;

  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed != null && parsed > 0 ? parsed : null;
}

/// Boxes que podem guardar os logs de atividade, na ordem de tentativa.
const List<String> kActivityLogBoxCandidates = [
  'activity_logs',
  'activity_log',
  'alfred_activity_logs',
  'alfred_activities',
  'activities',
  'workouts',
  'exercise_logs',
];

void enrichActivityRecord(Map<String, dynamic> item) {
  try {
    debugPrint('ALFRED enrich: item=$item');

    // 1) Campos no próprio registro (podem estar como texto).
    if (activityDistanceKmOf(item) == null) {
      for (final key in const ['distanceKm', 'distance', 'km']) {
        final distance = _parseFlexibleDistance(item[key]);
        if (distance != null) {
          item['distanceKm'] = distance;
          break;
        }
      }
    }

    final rawDuration = item['durationSeconds'];
    if (!(rawDuration is num && rawDuration > 0)) {
      final parsed = _parseFlexibleDuration(rawDuration);
      if (parsed != null) item['durationSeconds'] = parsed;
    }

    bool durationIsValid() =>
        item['durationSeconds'] is num &&
        (item['durationSeconds'] as num) > 0;

    bool distanceIsValid() => activityDistanceKmOf(item) != null;

    if (durationIsValid() && distanceIsValid()) return;

    // 2) Segue o ponteiro para o log real.
    final logKey = item['activityLogKey'];
    if (logKey == null) {
      debugPrint('ALFRED enrich: sem activityLogKey no registro');
      return;
    }

    final openCandidates = kActivityLogBoxCandidates
        .where((name) => Hive.isBoxOpen(name))
        .toList();

    debugPrint('ALFRED enrich: boxes candidatas abertas=$openCandidates');

    for (final name in openCandidates) {
      final box = Hive.box(name);
      dynamic raw = box.get(logKey);

      if (raw == null) {
        final intKey = int.tryParse(logKey.toString());
        if (intKey != null) raw = box.get(intKey);
      }

      if (raw is! Map) continue;

      final log = Map<String, dynamic>.from(raw);
      final sources = <Map<String, dynamic>>[log];

      for (final nestedKey in const ['data', 'activity', 'record']) {
        final nestedRaw = log[nestedKey];
        if (nestedRaw is Map) {
          sources.add(Map<String, dynamic>.from(nestedRaw));
        }
      }

      for (final source in sources) {
        if (!distanceIsValid()) {
          for (final key in const ['distanceKm', 'distance', 'km']) {
            if (!source.containsKey(key)) continue;

            final distance = _parseFlexibleDistance(source[key]);
            if (distance != null) {
              item['distanceKm'] = distance;
              break;
            }
          }
        }

        if (!durationIsValid()) {
          for (final key in const [
            'durationSeconds',
            'duration',
            'timeSeconds',
            'elapsedSeconds',
            'totalSeconds',
            'durationMinutes',
            'minutes',
          ]) {
            if (!source.containsKey(key)) continue;

            var seconds = _parseFlexibleDuration(source[key]);
            if (seconds == null) continue;

            if (key == 'durationMinutes' || key == 'minutes') {
              seconds *= 60;
            }

            item['durationSeconds'] = seconds;
            break;
          }
        }

        if (item['activityType'] == null && item['activityName'] == null) {
          final nameValue =
              source['activityName'] ?? source['activityType'] ?? source['name'];

          if (nameValue != null && nameValue.toString().trim().isNotEmpty) {
            item['activityName'] = nameValue.toString();
          }
        }

        if (durationIsValid() && distanceIsValid()) return;
      }

      debugPrint('ALFRED enrich: log encontrado em "$name" = $log');
      return;
    }

    debugPrint(
      'ALFRED enrich: log não encontrado (logKey=$logKey). '
      'Nenhuma das boxes candidatas tem essa chave.',
    );
  } catch (error) {
    debugPrint('ALFRED enrich erro: $error');
  }
}

// ── Listenables (para as telas reagirem a qualquer box envolvida) ──

class _NoopListenable extends ChangeNotifier {}

Listenable recordsListenable() {
  final listenables = <Listenable>[];

  for (final name in const [
    'alfred_box',
    'activity_logs',
    'alfred_shopping_products',
    'alfred_shopping_list',
    'alfred_shopping_saved',
    'alfred_reading_books',
    'alfred_reading_activities',
    'alfred_study_activities',
    'alfred_study_schedules',
    'alfred_study_types',
    'alfred_study_disciplines',
  ]) {
    try {
      if (Hive.isBoxOpen(name)) {
        listenables.add(Hive.box(name).listenable());
      }
    } catch (_) {}
  }

  if (listenables.isEmpty) return _NoopListenable();
  return Listenable.merge(listenables);
}

// ── Resumo por módulo (linha dos quadrados do dashboard) ──

String moduleSummary(String module, List<Map<String, dynamic>> items) {
  switch (module) {
    case 'Finanças':
      double? net;

      for (final item in items) {
        final value = financeAmountOf(item);
        if (value == null) continue;

        final isIncome = item['isIncome'] == true;
        net = (net ?? 0) + (isIncome ? value : -value);
      }

      return net != null ? formatBRL(net) : '${items.length} registros';

    case 'Atividade Física':
      var totalSeconds = 0;
      var totalKm = 0.0;

      for (final item in items) {
        totalSeconds += (item['durationSeconds'] as num?)?.toInt() ?? 0;
        totalKm += activityDistanceKmOf(item) ?? 0;
      }

      final parts = <String>[];

      if (totalSeconds > 0) {
        parts.add(formatReadingDuration(totalSeconds));
      }

      if (totalKm > 0) {
        final isWholeNumber = totalKm.truncateToDouble() == totalKm;
        parts.add(
          '${totalKm.toStringAsFixed(isWholeNumber ? 0 : 1)} km'
              .replaceAll('.', ','),
        );
      }

      return parts.isEmpty ? '${items.length} registros' : parts.join(' • ');

    case 'Leitura':
      var totalSeconds = 0;

      for (final item in items) {
        totalSeconds += (item['durationSeconds'] as num?)?.toInt() ?? 0;
      }

      return totalSeconds > 0
          ? formatReadingDuration(totalSeconds)
          : '${items.length} registros';

    case 'Estudos':
      final lessons = items
          .where(
            (item) => item['_key'].toString().startsWith('study_activity_'),
          )
          .length;

      return lessons > 0
          ? '$lessons ${lessons == 1 ? 'aula' : 'aulas'}'
          : '${items.length} registros';

    case 'Tarefas':
      final done = items.where((item) => item['isDone'] == true).length;
      final plural = items.length == 1 ? '' : 's';
      return '$done de ${items.length} concluída$plural';

    case 'Compras':
      var total = 0.0;
      var units = 0;

      for (final item in items) {
        final itemUnits = item['_shoppingUnits'];
        if (itemUnits is num) units += itemUnits.toInt();

        final lineTotal = item['_shoppingLineTotal'];
        if (lineTotal is num) total += lineTotal.toDouble();
      }

      if (total > 0) {
        return '$units ${units == 1 ? 'unidade' : 'unidades'} • '
            '${formatBRL(total)}';
      }

      return '${items.length} produtos';

    default:
      final plural = items.length == 1 ? '' : 's';
      return '${items.length} registro$plural';
  }
}

// ── Helpers para data das sessões de estudo ──

DateTime? _studyTimestampOf(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  }

  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final millis = int.tryParse(text);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    }

    final parsedDate = DateTime.tryParse(text);
    if (parsedDate != null) return parsedDate.toLocal();
  }

  return null;
}

// ── Núcleo: todos os registros do dia, mesclados, mais recentes primeiro ──

List<Map<String, dynamic>> itemsForDay(DateTime selectedDate) {
  final box = Hive.box('alfred_box');
  final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final end = start
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));

  final List<Map<String, dynamic>> items = [];

  // ── Registros do box principal ──
  for (final key in box.keys) {
    try {
      if (key.toString().startsWith('study_done_')) continue;

      final raw = box.get(key);
      if (raw == null) continue;

      final item = Map<String, dynamic>.from(raw as Map);
      final timestamp = recordTimestampOf(item);

      if (timestamp == null) continue;
      if (timestamp.isBefore(start) || timestamp.isAfter(end)) continue;

      item['_key'] = key;
      item['_ts'] = timestamp;

      if ((item['module']?.toString() ?? '') == 'Atividade Física') {
        enrichActivityRecord(item);
      }

      items.add(item);
    } catch (_) {}
  }

  // ── Leituras (alfred_reading_activities + alfred_reading_books) ──
  try {
    final booksBox = Hive.box('alfred_reading_books');
    final activitiesBox = Hive.box('alfred_reading_activities');

    for (final key in activitiesBox.keys) {
      final raw = activitiesBox.get(key);
      if (raw == null) continue;

      final activity = Map<String, dynamic>.from(raw as Map);
      final millis = activity['datetimeMillis'] as int?;
      if (millis == null) continue;

      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(millis).toLocal();

      if (timestamp.isBefore(start) || timestamp.isAfter(end)) continue;

      final rawBook = activity['bookKey'] != null
          ? booksBox.get(activity['bookKey'])
          : null;
      final book = rawBook is Map ? Map<String, dynamic>.from(rawBook) : null;

      final bookTitle = book?['title']?.toString() ?? 'Livro';
      final author = book?['author']?.toString() ?? '';
      final isAudio = readingBookIsAudio(book);
      final page = (activity['page'] as num?)?.toInt() ?? 0;
      final durationSeconds =
          (activity['durationSeconds'] as num?)?.toInt() ?? 0;

      String progress;

      if (isAudio) {
        progress = '${formatReadingDuration(durationSeconds)} lidos';

        final total = readingTotalSecondsOf(book);
        if (total != null && total > 0 && durationSeconds > 0) {
          final percentage = ((durationSeconds / total) * 100)
              .clamp(0, 100)
              .toStringAsFixed(0);
          progress += ' • $percentage%';
        }
      } else {
        progress = 'pág. $page';

        final totalPages = (book?['pages'] as num?)?.toInt() ?? 0;
        if (totalPages > 0 && page > 0) {
          final percentage =
              ((page / totalPages) * 100).clamp(0, 100).toStringAsFixed(0);
          progress += ' • $percentage%';
        }
      }

      items.add({
        'title': author.isEmpty ? bookTitle : '$bookTitle - $author',
        'module': 'Leitura',
        'isDone': activity['isDone'] as bool? ?? false,
        'timestamp': timestamp.toIso8601String(),
        '_key': 'reading_$key',
        '_ts': timestamp,
        '_readingProgress': progress,
        'page': page,
        'durationSeconds': durationSeconds,
      });
    }
  } catch (error) {
    debugPrint('Erro ao ler leituras: $error');
  }

  // ── Sessões de estudo realizadas (alfred_study_activities) ──
  try {
    final studyActivitiesBox = Hive.box('alfred_study_activities');
    final studyTypesBox = Hive.box('alfred_study_types');

    for (final key in studyActivitiesBox.keys) {
      try {
        final raw = studyActivitiesBox.get(key);
        if (raw == null) continue;

        final activity = Map<String, dynamic>.from(raw as Map);
        final timestamp = _studyTimestampOf(activity['datetimeMillis']);

        if (timestamp == null) {
          debugPrint(
            'ALFRED estudos: sessão $key sem datetimeMillis válido '
            '(${activity['datetimeMillis']}) — ignorada',
          );
          continue;
        }

        if (timestamp.isBefore(start) || timestamp.isAfter(end)) continue;

        final typeKey = activity['studyTypeKey'];
        final typeRaw = studyTypesBox.get(typeKey);

        String typeName = 'Estudo';
        if (typeRaw is Map) {
          final name = typeRaw['name']?.toString().trim();
          if (name != null && name.isNotEmpty) typeName = name;
        }

        String? disciplineName;
        int? totalLessons;
        final disciplineKey = activity['studyDisciplineKey'];

        if (disciplineKey != null &&
            Hive.isBoxOpen('alfred_study_disciplines')) {
          final disciplineRaw =
              Hive.box('alfred_study_disciplines').get(disciplineKey);

          if (disciplineRaw is Map) {
            disciplineName = disciplineRaw['name']?.toString();
            totalLessons =
                (disciplineRaw['totalLessons'] as num?)?.toInt();
          }
        }

        totalLessons ??=
            typeRaw is Map ? (typeRaw['totalLessons'] as num?)?.toInt() : null;

        final studyTitle = disciplineName == null || disciplineName.isEmpty
            ? typeName
            : '$typeName · $disciplineName';

        final rawLesson = activity['currentLesson'];
        final lessonNumber = rawLesson is num
            ? rawLesson.toInt()
            : int.tryParse(rawLesson?.toString() ?? '');

        final lessonLabel = (lessonNumber != null &&
                totalLessons != null &&
                totalLessons > 0)
            ? 'Aula $lessonNumber/$totalLessons'
            : 'Aula ${rawLesson ?? '?'}/${totalLessons ?? '?'}';

        final progressParts = <String>[lessonLabel];

        if (lessonNumber != null &&
            totalLessons != null &&
            totalLessons > 0) {
          final percentage =
              ((lessonNumber / totalLessons) * 100).round().clamp(0, 100);
          progressParts.add('$percentage%');
        }

        // O título principal fica somente com o tipo e a disciplina.
        // Aula e percentual serão mostrados na linha de detalhes.
        items.add({
          'title': studyTitle,
          'module': 'Estudos',
          'isDone': activity['isDone'] as bool? ?? false,
          'timestamp': timestamp.toIso8601String(),
          '_key': 'study_activity_$key',
          '_ts': timestamp,
          '_studyProgress': progressParts.join(' • '),
          'notes': activity['notes'],
          '_scheduleKey': activity['scheduleKey'],
          '_scheduledDay': activity['scheduledDay'],
        });
      } catch (error) {
        // Uma sessão com dados inválidos não impede as outras de aparecerem.
        debugPrint('ALFRED estudos: erro ao ler sessão $key: $error');
      }
    }
  } catch (error) {
    debugPrint('ALFRED estudos: erro no bloco de sessões realizadas: $error');
  }

  // ── Sessões agendadas (alfred_study_schedules) ──
  // O item agendado só aparece quando ainda NÃO foi realizado para o dia.
  try {
    final schedulesBox = Hive.box('alfred_study_schedules');
    final studyTypesBox = Hive.box('alfred_study_types');
    final studyActivitiesBox = Hive.box('alfred_study_activities');

    final selectedWeekday = selectedDate.weekday;
    final currentDayKey = DateFormat('yyyyMMdd').format(
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    );

    for (final key in schedulesBox.keys) {
      final raw = schedulesBox.get(key);
      if (raw == null) continue;

      final schedule = Map<String, dynamic>.from(raw as Map);
      final isActive = schedule['isActive'] as bool? ?? true;
      if (!isActive) continue;

      final weekdays = (schedule['weekdays'] as List?)?.cast<int>() ?? [];
      if (!weekdays.contains(selectedWeekday)) continue;

      final hour = schedule['timeHour'] as int? ?? 0;
      final minute = schedule['timeMinute'] as int? ?? 0;
      final timestamp = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        hour,
        minute,
      );

      final typeKey = schedule['studyTypeKey'];
      final typeRaw = studyTypesBox.get(typeKey);

      String typeName = 'Estudo';
      if (typeRaw is Map) {
        final name = typeRaw['name']?.toString().trim();
        if (name != null && name.isNotEmpty) typeName = name;
      }

      String? disciplineName;
      final disciplineKey = schedule['studyDisciplineKey'];

      if (disciplineKey != null &&
          Hive.isBoxOpen('alfred_study_disciplines')) {
        final disciplineRaw =
            Hive.box('alfred_study_disciplines').get(disciplineKey);

        if (disciplineRaw is Map) {
          disciplineName = disciplineRaw['name']?.toString();
        }
      }

      final studyTitle = disciplineName == null || disciplineName.isEmpty
          ? typeName
          : '$typeName · $disciplineName';

      final overrideKey = 'study_done_${key}_$currentDayKey';
      final overrideRaw = box.get(overrideKey);

      final isDoneOverride = overrideRaw != null
          ? (Map<String, dynamic>.from(overrideRaw as Map)['isDone'] as bool? ??
              false)
          : false;

      if (isDoneOverride) continue;

      var alreadyHasActivityForThisSchedule = false;

      try {
        for (final activityKey in studyActivitiesBox.keys) {
          final rawActivity = studyActivitiesBox.get(activityKey);
          if (rawActivity == null) continue;

          final activity = Map<String, dynamic>.from(rawActivity as Map);
          if (activity['scheduleKey'] == key &&
              activity['scheduledDay'] == currentDayKey) {
            alreadyHasActivityForThisSchedule = true;
            break;
          }
        }
      } catch (_) {}

      if (alreadyHasActivityForThisSchedule) continue;

      items.add({
        'title': '$studyTitle (agendado)',
        'module': 'Estudos',
        'isDone': isDoneOverride,
        'timestamp': timestamp.toIso8601String(),
        '_key': 'study_schedule_$key',
        '_ts': timestamp,
        '_readOnly': true,
      });
    }
  } catch (error) {
    debugPrint('ALFRED estudos: erro ao ler sessões agendadas: $error');
  }

  // Marca atraso apenas para Estudos.
  final nowInstant = DateTime.now();

  for (final item in items) {
    final scheduledAt = item['_ts'] as DateTime;
    final isDone = item['isDone'] as bool? ?? false;
    final module = (item['module'] as String? ?? '').toLowerCase();

    if (!isDone && module == 'estudos' && scheduledAt.isBefore(nowInstant)) {
      item['_isOverdue'] = true;
    }
  }

  // Mais recente primeiro (ordem decrescente de horário).
  items.sort(
    (a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime),
  );

  return items;
}