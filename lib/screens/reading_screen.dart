// lib/screens/reading_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Formatter que transforma a digitação de números em uma máscara
/// contínua no formato HH:MM:SS (ex: digitar "130" vira "00:01:30").
class _HmsInputFormatter extends TextInputFormatter {
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

// ---- Helpers de duração (audiobook) ----
int? parseDurationToSeconds(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final parts = s.split(':');
  int h = 0, m = 0, sec = 0;
  if (parts.length == 3) {
    h = int.tryParse(parts[0]) ?? -1;
    m = int.tryParse(parts[1]) ?? -1;
    sec = int.tryParse(parts[2]) ?? -1;
  } else if (parts.length == 2) {
    m = int.tryParse(parts[0]) ?? -1;
    sec = int.tryParse(parts[1]) ?? -1;
  } else {
    return null;
  }
  if (h < 0 || m < 0 || m > 59 || sec < 0 || sec > 59) return null;
  return h * 3600 + m * 60 + sec;
}

String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    Key? key,
    this.initialEditActivityKey,
  }) : super(key: key);

  final dynamic initialEditActivityKey;

  /// Útil para chamadas externas (ex.: Home) para abrir o modal de adicionar/editar
  /// Retorna a chave da atividade criada/atualizada ou null se cancelado.
  static Future<dynamic> showAddOrEditReading(BuildContext context, {dynamic existingKey}) async {
    final state = context.findAncestorStateOfType<_ReadingScreenState>();
    if (state != null) {
      return state._showAddOrEditReadingModal(existingKey: existingKey);
    }

    final booksBox = Hive.box('alfred_reading_books');
    final activitiesBox = Hive.box('alfred_reading_activities');

    if (booksBox.isEmpty) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) {
          final titleCtrl = TextEditingController();
          final pagesCtrl = TextEditingController();
          final durationCtrl = TextEditingController();
          bool isAudiobook = false;
          String audiobookProgressType = 'audio';
          return StatefulBuilder(
            builder: (ctx, setStateDialog) {
              return AlertDialog(
                title: const Text('Cadastrar primeiro livro'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isAudiobook,
                    title: const Text('É audiobook'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setStateDialog(() => isAudiobook = v),
                  ),
                  if (isAudiobook)
                    DropdownButtonFormField<String>(
                      value: audiobookProgressType,
                      decoration: const InputDecoration(labelText: 'Acompanhar audiobook por'),
                      items: const [
                        DropdownMenuItem(value: 'audio', child: Text('Horas de áudio')),
                        DropdownMenuItem(value: 'pages', child: Text('Páginas')),
                      ],
                      onChanged: (value) {
                        if (value != null) setStateDialog(() => audiobookProgressType = value);
                      },
                    ),
                  const SizedBox(height: 8),
                  if (isAudiobook && audiobookProgressType == 'audio')
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_HmsInputFormatter()],
                      decoration: const InputDecoration(labelText: 'Duração total (HH:MM:SS)', hintText: '00:00:00'),
                    )
                  else
                    TextField(controller: pagesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de páginas')),
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  ElevatedButton(onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    if (isAudiobook && audiobookProgressType == 'audio') {
                      final dur = parseDurationToSeconds(durationCtrl.text);
                      if (dur == null || dur <= 0) return;
                      booksBox.add({'title': title, 'author': '', 'publisher': '', 'pages': 0, 'isAudiobook': true, 'audiobookProgressType': 'audio', 'durationSeconds': dur, 'createdAt': DateTime.now().millisecondsSinceEpoch, 'isFinished': false});
                    } else {
                      final pages = int.tryParse(pagesCtrl.text.trim());
                      if (pages == null || pages <= 0) return;
                      booksBox.add({'title': title, 'author': '', 'publisher': '', 'pages': pages, 'isAudiobook': isAudiobook, 'audiobookProgressType': isAudiobook ? 'pages' : 'audio', 'durationSeconds': 0, 'createdAt': DateTime.now().millisecondsSinceEpoch, 'isFinished': false});
                    }
                    Navigator.pop(context, true);
                  }, child: const Text('Salvar')),
                ],
              );
            },
          );
        },
      );
      if (created != true) return null;
    }

    // Modal leve se a tela não estiver montada.
    return showDialog(
      context: context,
      builder: (_) {
        dynamic selectedBookKey = booksBox.keys.firstWhere(
          (k) {
            final b = (booksBox.get(k) as Map).cast<String, dynamic>();
            return b['isFinished'] != true;
          },
          orElse: () => booksBox.keys.first,
        );
        final pageCtrl = TextEditingController();
        final timeCtrl = TextEditingController();
        DateTime chosenDate = DateTime.now();

        return StatefulBuilder(builder: (ctx, setState) {
          final selectedBook = selectedBookKey != null ? (booksBox.get(selectedBookKey) as Map?)?.cast<String, dynamic>() : null;
          final isAudio = selectedBook?['isAudiobook'] == true &&
              (selectedBook?['audiobookProgressType'] ?? 'audio') == 'audio';
          return AlertDialog(
            title: const Text('Registrar leitura'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<dynamic>(
                  value: selectedBookKey,
                  items: booksBox.keys.where((k) {
                    final b = (booksBox.get(k) as Map).cast<String, dynamic>();
                    return b['isFinished'] != true;
                  }).map((k) {
                    final b = (booksBox.get(k) as Map).cast<String, dynamic>();
                    return DropdownMenuItem(value: k, child: Text(b['title'] ?? ''));
                  }).toList(),
                  onChanged: (v) => setState(() => selectedBookKey = v),
                  decoration: const InputDecoration(labelText: 'Livro'),
                ),
                const SizedBox(height: 12),
                if (isAudio)
                  TextField(
                    controller: timeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_HmsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Tempo ouvido (HH:MM:SS)', hintText: '00:00:00'),
                  )
                else
                  TextField(controller: pageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Página atual')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('Data e hora: ${DateFormat('dd/MM/yyyy HH:mm').format(chosenDate)}')),
                  TextButton(onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: chosenDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d == null) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(chosenDate));
                    if (t == null) return;
                    setState(() => chosenDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  }, child: const Text('Escolher')),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () {
                int durationSeconds = 0;
                int page = 0;
                if (isAudio) {
                  durationSeconds = parseDurationToSeconds(timeCtrl.text) ?? 0;
                  if (durationSeconds <= 0) return;
                } else {
                  final p = int.tryParse(pageCtrl.text.trim());
                  if (p == null || p < 0) return;
                  page = p;
                }
                final activity = {'bookKey': selectedBookKey, 'page': page, 'durationSeconds': durationSeconds, 'datetimeMillis': DateTime.now().millisecondsSinceEpoch, 'isDone': false};
                final newKey = activitiesBox.add(activity);
                Navigator.pop(ctx, newKey);
              }, child: const Text('Registrar')),
            ],
          );
        });
      },
    );
  }

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late Box booksBox; // Map: { title, author, publisher, pages, createdAt, isFinished, isAudiobook, audiobookProgressType, durationSeconds }
  late Box activitiesBox; // Map: { bookKey, page, durationSeconds, datetimeMillis, isDone }

  // Filtros do resumo
  int? _summaryFilterYear;
  int? _summaryFilterMonth;

 @override
  void initState() {
    super.initState();

    // As boxes devem já ter sido abertas no main.dart antes do runApp.
    booksBox = Hive.box('alfred_reading_books');
    activitiesBox = Hive.box('alfred_reading_activities');

    final activityKey = widget.initialEditActivityKey;
    if (activityKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAddOrEditReadingModal(existingKey: activityKey);
      });
    }
  }

  String _fmtDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _monthName(int m) {
    // nome do mês em pt_BR
    return DateFormat('MMMM', 'pt_BR').format(DateTime(2020, m, 1));
  }

  bool _isAudiobookBook(dynamic bookKey) {
    final raw = booksBox.get(bookKey);
    if (raw is Map) {
      return (raw as Map).cast<String, dynamic>()['isAudiobook'] == true;
    }
    return false;
  }

  int _listenedSecondsForBook(dynamic bookKey) {
    int total = 0;
    for (var a in activitiesBox.values) {
      final act = (a as Map).cast<String, dynamic>();
      if (act['bookKey'] == bookKey) {
        total += (act['durationSeconds'] as int?) ?? 0;
      }
    }
    return total;
  }

  Future<void> _addOrEditBook({dynamic bookKey}) async {
    final isEdit = bookKey != null;
    final initial = isEdit ? (booksBox.get(bookKey) as Map).cast<String, dynamic>() : null;

    final titleCtrl = TextEditingController(text: initial?['title'] ?? '');
    final authorCtrl = TextEditingController(text: initial?['author'] ?? '');
    final publisherCtrl = TextEditingController(text: initial?['publisher'] ?? '');
    final pagesCtrl = TextEditingController(text: initial?['pages']?.toString() ?? '');
    final initialDur = (initial?['durationSeconds'] as int?) ?? 0;
    final durationCtrl = TextEditingController(text: initialDur > 0 ? formatDuration(initialDur) : '');
    bool isAudiobook = initial?['isAudiobook'] == true;
    String audiobookProgressType = (initial?['audiobookProgressType'] ?? 'audio') as String;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Editar livro' : 'Cadastrar livro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 8),
                TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Autor')),
                const SizedBox(height: 8),
                TextField(controller: publisherCtrl, decoration: const InputDecoration(labelText: 'Editora (opcional)')),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isAudiobook,
                  title: const Text('É audiobook'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setStateDialog(() => isAudiobook = v),
                ),
                if (isAudiobook)
                  DropdownButtonFormField<String>(
                    value: audiobookProgressType,
                    decoration: const InputDecoration(labelText: 'Acompanhar audiobook por'),
                    items: const [
                      DropdownMenuItem(value: 'audio', child: Text('Horas de áudio')),
                      DropdownMenuItem(value: 'pages', child: Text('Páginas')),
                    ],
                    onChanged: (value) {
                      if (value != null) setStateDialog(() => audiobookProgressType = value);
                    },
                  ),
                const SizedBox(height: 8),
                if (isAudiobook && audiobookProgressType == 'audio')
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_HmsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Duração total (HH:MM:SS)', hintText: '00:00:00'),
                  )
                else
                  TextField(
                    controller: pagesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número de páginas'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                int pages = 0;
                int durationSeconds = 0;
                if (isAudiobook && audiobookProgressType == 'audio') {
                  durationSeconds = parseDurationToSeconds(durationCtrl.text) ?? 0;
                  if (title.isEmpty || durationSeconds <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe título e duração válida (00:00:00)')));
                    return;
                  }
                } else {
                  final p = int.tryParse(pagesCtrl.text.trim());
                  if (title.isEmpty || p == null || p <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe título e número válido de páginas')));
                    return;
                  }
                  pages = p;
                }
                final book = {
                  'title': title,
                  'author': authorCtrl.text.trim(),
                  'publisher': publisherCtrl.text.trim(),
                  'pages': pages,
                  'isAudiobook': isAudiobook,
                  'audiobookProgressType': audiobookProgressType,
                  'durationSeconds': durationSeconds,
                  'createdAt': isEdit ? (initial?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch) : DateTime.now().millisecondsSinceEpoch,
                  'isFinished': isEdit ? (initial?['isFinished'] ?? false) : false,
                };
                if (isEdit) booksBox.put(bookKey, book);
                else booksBox.add(book);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> _showAddOrEditReadingModal({dynamic existingKey}) async {
    final isEdit = existingKey != null;
    if (booksBox.isEmpty) {
      await _showAddBookInline();
      if (booksBox.isEmpty) return null;
    }

    // Verifica se há livros não finalizados
    final unfinishedBooks = booksBox.keys.where((k) {
      final b = (booksBox.get(k) as Map).cast<String, dynamic>();
      return b['isFinished'] != true;
    }).toList();

    if (unfinishedBooks.isEmpty && !isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos os livros estão finalizados. Não há livros para registrar leitura.')),
      );
      return null;
    }

    dynamic selectedBookKey;
    int? initialPage;
    int? initialDurationSeconds;
    DateTime chosenDate = DateTime.now();
    bool markAsFinished = false;

    if (isEdit) {
      final raw = activitiesBox.get(existingKey);
      if (raw is Map) {
        selectedBookKey = raw['bookKey'];
        initialPage = (raw['page'] as int?) ?? 0;
        initialDurationSeconds = (raw['durationSeconds'] as int?);
        chosenDate = DateTime.fromMillisecondsSinceEpoch((raw['datetimeMillis'] as int?) ?? DateTime.now().millisecondsSinceEpoch);
      }
    } else {
      selectedBookKey = unfinishedBooks.first;
    }

    final pageCtrl = TextEditingController(text: initialPage?.toString() ?? '');
    final timeCtrl = TextEditingController(text: (initialDurationSeconds != null && initialDurationSeconds > 0) ? formatDuration(initialDurationSeconds) : '');

    final res = await showDialog<dynamic>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setStateDialog) {
        final selectedBook = selectedBookKey != null ? (booksBox.get(selectedBookKey) as Map?)?.cast<String, dynamic>() : null;
        final isAudio = selectedBook?['isAudiobook'] == true &&
            (selectedBook?['audiobookProgressType'] ?? 'audio') == 'audio';
        return AlertDialog(
          title: Text(isEdit ? 'Editar leitura' : 'Registrar leitura'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<dynamic>(
                      value: selectedBookKey,
                      items: booksBox.keys.where((k) {
                        final b = (booksBox.get(k) as Map).cast<String, dynamic>();
                        return isEdit || b['isFinished'] != true;
                      }).map((k) {
                        final b = (booksBox.get(k) as Map).cast<String, dynamic>();
                        return DropdownMenuItem(value: k, child: Text('${b['title']}'));
                      }).toList(),
                      onChanged: (v) => setStateDialog(() => selectedBookKey = v),
                      decoration: const InputDecoration(labelText: 'Livro'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Criar novo livro',
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _showAddBookInline();
                      await Future.delayed(const Duration(milliseconds: 150));
                      return _showAddOrEditReadingModal(existingKey: existingKey);
                    },
                  )
                ]),
                const SizedBox(height: 12),
                if (isAudio)
                  TextField(
                    controller: timeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_HmsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Tempo ouvido (HH:MM:SS)', hintText: '00:00:00'),
                  )
                else
                  TextField(
                    controller: pageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Página atual'),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Data e hora: ${DateFormat('dd/MM/yyyy HH:mm').format(chosenDate)}')),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: chosenDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (d == null) return;
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(chosenDate));
                        if (t == null) return;
                        setStateDialog(() {
                          chosenDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        });
                      },
                      child: const Text('Escolher'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: markAsFinished,
                  title: const Text('Finalizar este livro'),
                  subtitle: const Text('Ele não aparecerá mais no registro'),
                  onChanged: (v) => setStateDialog(() => markAsFinished = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                int durationSeconds = 0;
                int page = 0;
                if (isAudio) {
                  durationSeconds = parseDurationToSeconds(timeCtrl.text) ?? 0;
                  if (durationSeconds <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um tempo válido no formato 00:00:00')));
                    return;
                  }
                } else {
                  final p = int.tryParse(pageCtrl.text.trim());
                  if (p == null || p < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe uma página válida')));
                    return;
                  }
                  page = p;
                }
                final dtMillis = chosenDate.millisecondsSinceEpoch;
                final activity = {
                  'bookKey': selectedBookKey,
                  'page': page,
                  'durationSeconds': durationSeconds,
                  'datetimeMillis': dtMillis,
                  'isDone': false,
                };
                if (isEdit) {
                  activitiesBox.put(existingKey, activity);
                  Navigator.pop(context, existingKey);
                } else {
                  final newKey = activitiesBox.add(activity);
                  // Se marcar como finalizado, atualiza o objeto do livro
                  if (markAsFinished) {
                    final bookData = Map<String, dynamic>.from(booksBox.get(selectedBookKey));
                    bookData['isFinished'] = true;
                    booksBox.put(selectedBookKey, bookData);
                  }
                  Navigator.pop(context, newKey);
                }
              },
              child: Text(isEdit ? 'Salvar' : 'Registrar'),
            ),
          ],
        );
      }),
    );

    setState(() {});
    return res;
  }

  Future<void> _showAddBookInline() async {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final pagesCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    bool isAudiobook = false;
    String audiobookProgressType = 'audio';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Cadastrar livro'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 8),
            TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Autor')),
            const SizedBox(height: 8),
            SwitchListTile(
              value: isAudiobook,
              title: const Text('É audiobook'),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setStateDialog(() => isAudiobook = v),
            ),
            if (isAudiobook)
              DropdownButtonFormField<String>(
                value: audiobookProgressType,
                decoration: const InputDecoration(labelText: 'Acompanhar audiobook por'),
                items: const [
                  DropdownMenuItem(value: 'audio', child: Text('Horas de áudio')),
                  DropdownMenuItem(value: 'pages', child: Text('Páginas')),
                ],
                onChanged: (value) {
                  if (value != null) setStateDialog(() => audiobookProgressType = value);
                },
              ),
            const SizedBox(height: 8),
            if (isAudiobook && audiobookProgressType == 'audio')
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_HmsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Duração total (HH:MM:SS)', hintText: '00:00:00'),
              )
            else
              TextField(controller: pagesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de páginas')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () {
              final title = titleCtrl.text.trim();
              final author = authorCtrl.text.trim();
              int pages = 0;
              int durationSeconds = 0;
              if (isAudiobook && audiobookProgressType == 'audio') {
                durationSeconds = parseDurationToSeconds(durationCtrl.text) ?? 0;
                if (title.isEmpty || durationSeconds <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe título e duração válida (00:00:00)')),
                  );
                  return;
                }
              } else {
                final p = int.tryParse(pagesCtrl.text.trim());
                if (title.isEmpty || p == null || p <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe título, autor e número válido de páginas')),
                  );
                  return;
                }
                pages = p;
              }
              booksBox.add({
                'title': title,
                'author': author,
                'publisher': '',
                'pages': pages,
                'isAudiobook': isAudiobook,
                'audiobookProgressType': audiobookProgressType,
                'durationSeconds': durationSeconds,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
                'isFinished': false,
              });
              Navigator.pop(context);
              setState(() {});
            }, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _lastActivityForBook(dynamic bookKey) {
    Map<String, dynamic>? best;
    for (var a in activitiesBox.values) {
      final act = (a as Map).cast<String, dynamic>();
      if (act['bookKey'] == bookKey) {
        if (best == null || (act['datetimeMillis'] as int) > (best['datetimeMillis'] as int)) {
          best = act;
        }
      }
    }
    return best;
  }

  void _confirmDeleteBook(dynamic bookKey) {
    final book = (booksBox.get(bookKey) as Map).cast<String, dynamic>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remover "${book['title']}"?'),
        content: const Text('Deseja remover o livro e todas as atividades relacionadas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final keysToRemove = <dynamic>[];
              for (var k in activitiesBox.keys) {
                final act = (activitiesBox.get(k) as Map).cast<String, dynamic>();
                if (act['bookKey'] == bookKey) keysToRemove.add(k);
              }
              for (var k in keysToRemove) activitiesBox.delete(k);
              booksBox.delete(bookKey);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Widget _booksTab() {
    return ValueListenableBuilder(
      valueListenable: booksBox.listenable(),
      builder: (context, Box b, _) {
        if (b.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Nenhum livro cadastrado.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: _showAddBookInline, icon: const Icon(Icons.add), label: const Text('Cadastrar livro')),
            ]),
          );
        }

        final entries = b.keys.map((k) {
          final m = (b.get(k) as Map).cast<String, dynamic>();
          return {'key': k, 'data': m};
        }).toList();

        // Ordena por última atividade (mais recente primeiro); sem atividade, usa createdAt
        entries.sort((x, y) {
          final xLast = _lastActivityForBook(x['key']);
          final yLast = _lastActivityForBook(y['key']);
          final xMillis = xLast != null
              ? (xLast['datetimeMillis'] as int)
              : ((x['data']['createdAt'] as int?) ?? 0);
          final yMillis = yLast != null
              ? (yLast['datetimeMillis'] as int)
              : ((y['data']['createdAt'] as int?) ?? 0);
          return yMillis.compareTo(xMillis);
        });

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final e = entries[i];
            final key = e['key'];
            final Map book = e['data'] as Map;
            final isAudio = book['isAudiobook'] == true &&
                (book['audiobookProgressType'] ?? 'audio') == 'audio';
            final total = (book['pages'] as int);
            final totalSeconds = (book['durationSeconds'] as int?) ?? 0;
            final listened = isAudio ? _listenedSecondsForBook(key) : 0;
            final last = _lastActivityForBook(key);
            final lastPage = last != null ? (last['page'] as int) : 0;
            final percent = isAudio
                ? ((listened / (totalSeconds > 0 ? totalSeconds : 1)) * 100).clamp(0, 100)
                : ((lastPage / (total > 0 ? total : 1)) * 100).clamp(0, 100);
            final finished = isAudio ? (listened >= totalSeconds && totalSeconds > 0) : (lastPage >= total && total > 0);
            final lastUpdated = last != null ? _fmtDateTime(last['datetimeMillis'] as int) : '—';
            final isFinished = book['isFinished'] == true;
            final author = book['author'] as String? ?? '';

            return ListTile(
              leading: book['isAudiobook'] == true ? const Icon(Icons.headphones) : const Icon(Icons.menu_book),
              title: Text(book['title'] ?? ''),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (author.isNotEmpty)
                  Text('por $author', style: const TextStyle(fontStyle: FontStyle.italic))
                else
                  const SizedBox(height: 4),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: isAudio ? (totalSeconds > 0 ? (listened / totalSeconds) : 0) : (total > 0 ? (lastPage / total) : 0)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(
                      isAudio
                          ? 'Áudio: ${formatDuration(listened)} / ${formatDuration(totalSeconds)} (${percent.toStringAsFixed(0)}%)'
                          : 'Pág. $lastPage / $total (${percent.toStringAsFixed(0)}%)',
                    ),
                  ),
                  if (isFinished || finished)
                    const Text('Finalizado', style: TextStyle(color: Colors.blue)),
                ]),
                const SizedBox(height: 6),
                Text('Última atualização: $lastUpdated', style: const TextStyle(fontSize: 12)),
              ]),
              isThreeLine: true,
              trailing: isFinished
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _addOrEditBook(bookKey: key)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDeleteBook(key)),
                  ]),
              onTap: () {
                final acts = <Map<String, dynamic>>[];
                for (var aKey in activitiesBox.keys) {
                  final a = (activitiesBox.get(aKey) as Map).cast<String, dynamic>();
                  if (a['bookKey'] == key) {
                    final copy = Map<String, dynamic>.from(a);
                    copy['_key'] = aKey;
                    acts.add(copy);
                  }
                }
                acts.sort((a, b) => (b['datetimeMillis'] as int).compareTo(a['datetimeMillis'] as int));
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(book['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (author.isNotEmpty)
                          Text('por $author', style: const TextStyle(fontStyle: FontStyle.italic))
                        else
                          const SizedBox(height: 4),
                        const SizedBox(height: 8),
                        Text('Progresso: ${percent.toStringAsFixed(0)}%'),
                        if (isAudio) Text('Ouvido: ${formatDuration(listened)} de ${formatDuration(totalSeconds)}'),
                        if (isFinished) const Text('Status: Finalizado', style: TextStyle(color: Colors.blue)),
                        const SizedBox(height: 12),
                        const Text('Histórico de leituras:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Flexible(
                          child: acts.isEmpty
                              ? const Text('Nenhuma leitura registrada para este livro.')
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: acts.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (ctx, idx) {
                                    final a = acts[idx];
                                    return ListTile(
                                      title: Text(isAudio ? 'Áudio: ${formatDuration((a['durationSeconds'] as int?) ?? 0)}' : 'Pág. ${a['page']}'),
                                      subtitle: Text(_fmtDateTime(a['datetimeMillis'] as int)),
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
                                          Navigator.pop(ctx);
                                          _showAddOrEditReadingModal(existingKey: a['_key']);
                                        }),
                                        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                                          showDialog(context: ctx, builder: (_) => AlertDialog(
                                            title: const Text('Remover atividade?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
                                                activitiesBox.delete(a['_key']);
                                                Navigator.pop(ctx);
                                                setState(() {});
                                              }, child: const Text('Remover')),
                                            ],
                                          ));
                                        }),
                                      ]),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _addOrEditBook(bookKey: key);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar Livro'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddOrEditReadingModal();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Registrar Leitura'),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _activitiesTab() {
    return ValueListenableBuilder(
      valueListenable: activitiesBox.listenable(),
      builder: (context, Box b, _) {
        if (b.isEmpty) {
          return const Center(child: Text('Nenhuma atividade de leitura registrada.'));
        }

        final entries = b.keys.map((k) {
          final m = (b.get(k) as Map).cast<String, dynamic>();
          final copy = Map<String, dynamic>.from(m);
          copy['_key'] = k;
          return copy;
        }).toList();

        entries.sort((a, b) => (b['datetimeMillis'] as int).compareTo(a['datetimeMillis'] as int));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final act = entries[i];
            final key = act['_key'];
            final book = (booksBox.get(act['bookKey']) as Map?)?.cast<String, dynamic>();
            final title = book != null ? (book['title'] ?? 'Livro') : 'Livro removido';
            final author = book != null ? (book['author'] as String? ?? '') : '';
            final isAudio = book?['isAudiobook'] == true;
            final dur = (act['durationSeconds'] as int?) ?? 0;
            final isDone = act['isDone'] as bool? ?? false;

            return ListTile(
              leading: GestureDetector(
                onTap: () {
                  final raw = activitiesBox.get(key);
                  if (raw is Map) {
                    final m = Map<String, dynamic>.from(raw);
                    m['isDone'] = !(m['isDone'] as bool? ?? false);
                    activitiesBox.put(key, m);
                    setState(() {});
                  }
                },
                child: Container(
                  width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: isDone ? Colors.green : Colors.grey[300]),
                  child: Icon(isDone ? Icons.check : (isAudio ? Icons.headphones : Icons.menu_book), color: isDone ? Colors.white : Colors.black54, size: 18),
                ),
              ),
              title: Text('$title${author.isNotEmpty ? ' - $author' : ''} — ${isAudio ? formatDuration(dur) : 'pág. ${act['page']}'}',
                  style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none)),
              subtitle: Text(_fmtDateTime(act['datetimeMillis'] as int)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddOrEditReadingModal(existingKey: key)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
                  showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Remover atividade?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
                        activitiesBox.delete(key);
                        Navigator.pop(context);
                        setState(() {});
                      }, child: const Text('Remover')),
                    ],
                  ));
                }),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _summaryTab() {
    // Helper para agrupar por "yyyy-MM" (usa lastActivity quando houver)
    String _monthKeyFromMillis(int millis) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      return DateFormat('yyyy-MM').format(dt);
    }

    String _monthLabelFromMillis(int millis) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      return DateFormat('MMMM yyyy', 'pt_BR').format(dt);
    }

    // Constrói mapa chave->lista de livros (Map com key e data)
    Map<String, List<Map<String, dynamic>>> _groupBooksByMonth(List<Map<String, dynamic>> books) {
      final Map<String, List<Map<String, dynamic>>> out = {};
      for (var b in books) {
        int? millis;
        if (b.containsKey('lastActivityMillis') && b['lastActivityMillis'] != null) {
          millis = b['lastActivityMillis'] as int;
        } else if (b['createdAt'] != null) {
          millis = b['createdAt'] as int;
        } else {
          millis = DateTime.now().millisecondsSinceEpoch;
        }
        final key = _monthKeyFromMillis(millis);
        out.putIfAbsent(key, () => []).add(b);
      }
      return out;
    }

    return ValueListenableBuilder(
      valueListenable: booksBox.listenable(),
      builder: (context, Box b, _) {
        if (b.isEmpty) {
          return const Center(child: Text('Nenhum livro cadastrado para mostrar resumo.'));
        }

        // Prepara lista com dados enriquecidos (lastActivity, lastPage, percent)
        final enriched = <Map<String, dynamic>>[];

        for (var key in b.keys) {
          final raw = (b.get(key) as Map).cast<String, dynamic>();
          final book = Map<String, dynamic>.from(raw);
          book['_key'] = key;
          final isAudio = book['isAudiobook'] == true &&
              (book['audiobookProgressType'] ?? 'audio') == 'audio';
          final totalSeconds = (book['durationSeconds'] as int?) ?? 0;
          final total = (book['pages'] as int);
          final listened = isAudio ? _listenedSecondsForBook(key) : 0;
          final last = _lastActivityForBook(key);
          final lastPage = last != null ? (last['page'] as int) : 0;
          final lastMillis = last != null ? (last['datetimeMillis'] as int) : null;
          final percent = isAudio
              ? ((listened / (totalSeconds > 0 ? totalSeconds : 1)) * 100).clamp(0, 100)
              : ((lastPage / (total > 0 ? total : 1)) * 100).clamp(0, 100);
          final isFinishedFlag = book['isFinished'] == true;
          final finishedByProgress = isAudio ? (listened >= totalSeconds && totalSeconds > 0) : (lastPage >= total && total > 0);
          final isConcluded = isFinishedFlag || finishedByProgress;
          book['lastPage'] = lastPage;
          book['lastActivityMillis'] = lastMillis;
          book['percent'] = percent;
          book['isConcluded'] = isConcluded;
          book['isAudio'] = isAudio;
          book['listenedSeconds'] = listened;
          book['totalSeconds'] = totalSeconds;
          enriched.add(book);
        }

        // --- Preparar opções de filtro (anos e meses existentes) ---
        final yearsSet = <int>{};
        for (var book in enriched) {
          final millis = book['lastActivityMillis'] ?? book['createdAt'];
          final dt = DateTime.fromMillisecondsSinceEpoch((millis ?? DateTime.now().millisecondsSinceEpoch) as int).toLocal();
          yearsSet.add(dt.year);
        }
        final years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

        List<int> monthsAvailable = [];
        if (_summaryFilterYear != null) {
          final set = <int>{};
          for (var book in enriched) {
            final millis = book['lastActivityMillis'] ?? book['createdAt'];
            final dt = DateTime.fromMillisecondsSinceEpoch((millis ?? DateTime.now().millisecondsSinceEpoch) as int).toLocal();
            if (dt.year == _summaryFilterYear) set.add(dt.month);
          }
          monthsAvailable = set.toList()..sort((a, b) => b.compareTo(a));
        } else {
          final set = <int>{};
          for (var book in enriched) {
            final millis = book['lastActivityMillis'] ?? book['createdAt'];
            final dt = DateTime.fromMillisecondsSinceEpoch((millis ?? DateTime.now().millisecondsSinceEpoch) as int).toLocal();
            set.add(dt.month);
          }
          monthsAvailable = set.toList()..sort((a, b) => b.compareTo(a));
        }

        bool _passesFilter(Map<String, dynamic> book) {
          final millis = book['lastActivityMillis'] ?? book['createdAt'];
          final dt = DateTime.fromMillisecondsSinceEpoch((millis ?? DateTime.now().millisecondsSinceEpoch) as int).toLocal();
          if (_summaryFilterYear != null && dt.year != _summaryFilterYear) return false;
          if (_summaryFilterMonth != null && dt.month != _summaryFilterMonth) return false;
          return true;
        }

        // Aplicar filtro
        final filteredEnriched = enriched.where((e) => _passesFilter(e)).toList();

        // Separar em andamento e concluídos a partir da lista filtrada
        final inProgress = filteredEnriched.where((e) => e['isConcluded'] != true).toList();
        final concluded = filteredEnriched.where((e) => e['isConcluded'] == true).toList();

        // Contagens do topo (refletindo filtros)
        final totalBooks = filteredEnriched.length;
        // contar sessões e tempo de áudio no período filtrado (baseado em datetimeMillis)
        int totalSessions = 0;
        int totalAudioSeconds = 0;
        for (var a in activitiesBox.values) {
          final act = (a as Map).cast<String, dynamic>();
          final dt = DateTime.fromMillisecondsSinceEpoch(act['datetimeMillis'] as int).toLocal();
          if (_summaryFilterYear != null && dt.year != _summaryFilterYear) continue;
          if (_summaryFilterMonth != null && dt.month != _summaryFilterMonth) continue;
          totalSessions++;
          totalAudioSeconds += (act['durationSeconds'] as int?) ?? 0;
        }
        final concludedCount = concluded.length;

        // Agrupar por mês/ano (usa lastActivityMillis quando existir, senão createdAt)
        final groupedInProgress = _groupBooksByMonth(inProgress);
        final groupedConcluded = _groupBooksByMonth(concluded);

        // Ordenar keys descendente (mes mais recente primeiro)
        final sortedKeysInProgress = groupedInProgress.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        final sortedKeysConcluded = groupedConcluded.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        Widget _buildTopCards() {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        const Icon(Icons.menu_book, size: 28, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text('$totalBooks', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Livros', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        const Icon(Icons.history, size: 28, color: Colors.purple),
                        const SizedBox(height: 8),
                        Text('$totalSessions', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Sessões', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        const Icon(Icons.emoji_events, size: 28, color: Colors.green),
                        const SizedBox(height: 8),
                        Text('$concludedCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Concluídos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        const Icon(Icons.headphones, size: 28, color: Colors.teal),
                        const SizedBox(height: 8),
                        Text(formatDuration(totalAudioSeconds), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Áudio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget _buildFilters() {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _summaryFilterYear,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todos os anos')),
                    ...years.map((y) => DropdownMenuItem<int?>(value: y, child: Text(y.toString()))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _summaryFilterYear = v;
                      // ao mudar ano, limpa mês (forçar reescolha)
                      _summaryFilterMonth = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _summaryFilterMonth,
                  decoration: const InputDecoration(labelText: 'Mês'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todos os meses')),
                    ...monthsAvailable.map((m) => DropdownMenuItem<int?>(value: m, child: Text(_monthName(m)))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _summaryFilterMonth = v;
                    });
                  },
                ),
              ),
            ]),
          );
        }

        Widget _buildGroupList(Map<String, List<Map<String, dynamic>>> grouped, List<String> sortedKeys) {
          if (grouped.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Text('Nenhum registro.'),
            );
          }

          return Column(
            children: sortedKeys.map((monthKey) {
              final list = grouped[monthKey]!;
              // determine a millis para label: prefer lastActivity of first item, or createdAt
              final sampleMillis = list.first['lastActivityMillis'] ?? list.first['createdAt'];
              final monthLabel = _monthLabelFromMillis(sampleMillis as int);
              // ordenar livros dentro do mês por lastActivity desc
              list.sort((a, b) {
                final aMillis = a['lastActivityMillis'] ?? a['createdAt'];
                final bMillis = b['lastActivityMillis'] ?? b['createdAt'];
                return (bMillis as int).compareTo(aMillis as int);
              });

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: list.map((book) {
                          final title = book['title'] ?? '';
                          final author = (book['author'] as String?) ?? '';
                          final isAudio = book['isAudio'] == true;
                          final isAudiobook = book['isAudiobook'] == true;
                          final lastPage = book['lastPage'] as int? ?? 0;
                          final total = (book['pages'] as int?) ?? 0;
                          final percent = (book['percent'] as num?)?.toDouble() ?? 0.0;
                          final lastMillis = book['lastActivityMillis'] as int?;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: isAudiobook ? const Icon(Icons.headphones) : const Icon(Icons.menu_book),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if ((author).isNotEmpty) Text('por $author', style: const TextStyle(fontStyle: FontStyle.italic)),
                              const SizedBox(height: 6),
                              Text(isAudio
                                  ? 'Áudio: ${formatDuration((book['listenedSeconds'] as int?) ?? 0)} / ${formatDuration((book['totalSeconds'] as int?) ?? 0)} (${percent.toStringAsFixed(0)}%)'
                                  : 'Pág. $lastPage / $total (${percent.toStringAsFixed(0)}%)'),
                              const SizedBox(height: 4),
                              Text('Última: ${lastMillis != null ? _fmtDateTime(lastMillis) : '—'}', style: const TextStyle(fontSize: 12)),
                            ]),
                            trailing: (book['isConcluded'] == true)
                              ? const Icon(Icons.check_circle, color: Colors.blue)
                              : null,
                            onTap: () {
                              // abrir detalhes como antes
                              final acts = <Map<String, dynamic>>[];
                              for (var aKey in activitiesBox.keys) {
                                final a = (activitiesBox.get(aKey) as Map).cast<String, dynamic>();
                                if (a['bookKey'] == book['_key']) {
                                  final copy = Map<String, dynamic>.from(a);
                                  copy['_key'] = aKey;
                                  acts.add(copy);
                                }
                              }
                              acts.sort((a, b) => (b['datetimeMillis'] as int).compareTo(a['datetimeMillis'] as int));
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(book['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      if ((book['author'] as String?)?.isNotEmpty == true)
                                        Text('por ${book['author']}', style: const TextStyle(fontStyle: FontStyle.italic))
                                      else
                                        const SizedBox(height: 4),
                                      const SizedBox(height: 8),
                                      Text('Progresso: ${percent.toStringAsFixed(0)}%'),
                                      if (isAudio) Text('Ouvido: ${formatDuration((book['listenedSeconds'] as int?) ?? 0)} de ${formatDuration((book['totalSeconds'] as int?) ?? 0)}'),
                                      if (book['isConcluded'] == true) const Text('Status: Finalizado', style: TextStyle(color: Colors.blue)),
                                      const SizedBox(height: 12),
                                      const Text('Histórico de leituras:', style: TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: acts.isEmpty
                                            ? const Text('Nenhuma leitura registrada para este livro.')
                                            : ListView.separated(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: acts.length,
                                                separatorBuilder: (_, __) => const Divider(),
                                                itemBuilder: (ctx, idx) {
                                                  final a = acts[idx];
                                                  return ListTile(
                                                    title: Text(isAudio ? 'Áudio: ${formatDuration((a['durationSeconds'] as int?) ?? 0)}' : 'Pág. ${a['page']}'),
                                                    subtitle: Text(_fmtDateTime(a['datetimeMillis'] as int)),
                                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
                                                        Navigator.pop(ctx);
                                                        _showAddOrEditReadingModal(existingKey: a['_key']);
                                                      }),
                                                      IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                                                        showDialog(context: ctx, builder: (_) => AlertDialog(
                                                          title: const Text('Remover atividade?'),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
                                                              activitiesBox.delete(a['_key']);
                                                              Navigator.pop(ctx);
                                                              setState(() {});
                                                            }, child: const Text('Remover')),
                                                          ],
                                                        ));
                                                      }),
                                                    ]),
                                                  );
                                                },
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _addOrEditBook(bookKey: book['_key']);
                                            },
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Editar Livro'),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _showAddOrEditReadingModal();
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Registrar Leitura'),
                                          ),
                                        ],
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ]),
              );
            }).toList(),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // filtros
            const SizedBox(height: 8),
            _buildFilters(),
            const SizedBox(height: 8),
            _buildTopCards(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Text('Em andamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            if (inProgress.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text('Nenhum livro em andamento.'))
            else
              _buildGroupList(groupedInProgress, sortedKeysInProgress),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Text('Concluídos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            if (concluded.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text('Nenhum livro concluído.'))
            else
              _buildGroupList(groupedConcluded, sortedKeysConcluded),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leitura'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Livros', icon: Icon(Icons.book)),
            Tab(text: 'Leituras', icon: Icon(Icons.history)),
            Tab(text: 'Resumo', icon: Icon(Icons.show_chart)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.library_add),
              onPressed: _showAddBookInline,
              tooltip: 'Cadastrar livro',
            ),
          ],
        ),
        body: TabBarView(children: [
          _booksTab(),
          _activitiesTab(),
          _summaryTab(),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddOrEditReadingModal(),
          child: const Icon(Icons.add),
          tooltip: 'Adicionar atividade de leitura',
        ),
      ),
    );
  }
}