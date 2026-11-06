// lib/widgets/finance_record_form.dart

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FinanceRecordForm extends StatefulWidget {
  const FinanceRecordForm({
    Key? key,
    this.recordKey,
    this.existing,
    this.initialDescription,
    this.initialRawText,
    this.initialEventIds,
    this.onSaved,
    this.embedded = false,
    required this.availableCards,
    required this.showCardForm,
  }) : super(key: key);

  final dynamic recordKey;
  final Map<String, dynamic>? existing;
  final String? initialDescription;
  final String? initialRawText;
  final List<String>? initialEventIds;
  final VoidCallback? onSaved;
  final bool embedded;

  final List<Map<String, dynamic>> Function() availableCards;
  final Future<String?> Function(dynamic hiveKey) showCardForm;

  @override
  State<FinanceRecordForm> createState() => _FinanceRecordFormState();
}

class _FinanceRecordFormState extends State<FinanceRecordForm> {
  final box = Hive.box('alfred_box');
  final categoriesBox = Hive.box('alfred_finance_categories');
  final Box cardsBox = Hive.box('cards');
  final Box eventsBox = Hive.box('finance_events');

  late List<String> selectedEventIds;

  final List<String> paymentMethods = [
    'Dinheiro/Pix',
    'Débito',
    'Crédito',
  ];

  final List<String> incomeMethods = [
    'Transferência',
    'PIX',
    'Dinheiro',
  ];

  late TextEditingController titleCtrl;
  late TextEditingController amountCtrl;
  late TextEditingController installmentCtrl;

  late DateTime selectedDate;
  late TimeOfDay selectedTime;

  late String selectedCategory;
  late String selectedPaymentMethod;

  String? selectedCardKey;
  String? selectedCardName;
  String? selectedCardType;

  bool isIncomeSelected = false;
  bool isSubscription = false;

  List<String> catOptions = [];
  List<Map<String, dynamic>> filteredCards = [];

  // Campos que o usuário já editou à mão não são sobrescritos
  // pelo interpretador do texto rápido.
  bool _typeManuallyEdited = false;
  bool _descriptionManuallyEdited = false;
  bool _methodManuallyEdited = false;
  bool _amountManuallyEdited = false;

  bool get isEditing => widget.recordKey != null;

  bool get existingIsIncome =>
      widget.existing != null && widget.existing!['isIncome'] == true;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    final existingEvents = existing?['eventIds'];

    selectedEventIds = existingEvents is List
        ? existingEvents.map((eventId) => eventId.toString()).toList()
        : List<String>.from(widget.initialEventIds ?? const <String>[]);

    titleCtrl = TextEditingController(
      text: existing != null
          ? (existing['title'] as String? ?? '')
          : (widget.initialDescription ?? ''),
    );

    amountCtrl = TextEditingController(
      text: existing != null && existing['amount'] is num
          ? existing['amount'].toString()
          : '',
    );

    installmentCtrl = TextEditingController(
      text: existing != null && existing['installmentTotal'] != null
          ? existing['installmentTotal'].toString()
          : '1',
    );

    final baseTimestamp = existing != null
        ? DateTime.tryParse(existing['timestamp'] as String? ?? '') ??
            DateTime.now()
        : DateTime.now();

    selectedDate = baseTimestamp;
    selectedTime = TimeOfDay(
      hour: baseTimestamp.hour,
      minute: baseTimestamp.minute,
    );

    selectedCategory = _normalizeCategory(existing?['category']);

    selectedPaymentMethod = existing?['paymentMethod'] as String? ??
        (existingIsIncome ? incomeMethods.first : paymentMethods.first);

    isIncomeSelected = existingIsIncome;

    selectedCardKey = existing?['cardId'] as String?;
    selectedCardName = existing?['cardName'] as String?;
    selectedCardType = existing?['cardType'] as String?;

    if (selectedCardType == 'Crédito') {
      selectedPaymentMethod = 'Crédito';
    } else if (selectedCardType == 'Débito') {
      selectedPaymentMethod = 'Débito';
    }

    isSubscription = _readSubscriptionValue(existing);

    _loadCategories();
    _rebuildFilteredCards();

    if (!isEditing && (widget.initialRawText?.trim().isNotEmpty ?? false)) {
      _applyParsedText(widget.initialRawText!);
    }
  }

  @override
  void didUpdateWidget(covariant FinanceRecordForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (isEditing) return;

    final rawChanged =
        (widget.initialRawText ?? '') != (oldWidget.initialRawText ?? '');

    if (rawChanged) {
      setState(() {
        _applyParsedText(widget.initialRawText ?? '');
      });
    } else if (widget.initialDescription != oldWidget.initialDescription &&
        widget.initialDescription != null &&
        widget.initialDescription!.trim().isNotEmpty &&
        titleCtrl.text.trim().isEmpty) {
      titleCtrl.text = widget.initialDescription!.trim();
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    installmentCtrl.dispose();
    super.dispose();
  }

  String _normalizeCategory(dynamic category) {
    final value = (category as String?)?.trim() ?? '';
    return value.isEmpty ? '(Sem categoria)' : value;
  }

  bool _readSubscriptionValue(Map<String, dynamic>? existing) {
    if (existing == null) return false;

    if (existing.containsKey('isSubscription')) {
      final value = existing['isSubscription'];

      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }

    final category = (existing['category'] as String?) ?? '';
    return category.trim().toLowerCase() == 'assinaturas';
  }

  Widget _buildEventSelector() {
    final selectedNames = _selectedEventNames();

    return InkWell(
      onTap: _openEventPicker,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Eventos (opcional)',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedNames.isEmpty ? 'Nenhum evento' : selectedNames.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            color: selectedNames.isEmpty ? Colors.grey : null,
          ),
        ),
      ),
    );
  }

  List<String> _selectedEventNames() {
    final names = <String>[];

    for (final key in eventsBox.keys) {
      final raw = eventsBox.get(key);

      if (raw is Map) {
        final event = Map<String, dynamic>.from(raw);
        final id = (event['id'] ?? key).toString();

        if (selectedEventIds.contains(id)) {
          names.add(event['name'] as String? ?? 'Evento');
        }
      }
    }

    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<void> _openEventPicker() async {
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final events = <Map<String, dynamic>>[];

            for (final key in eventsBox.keys) {
              final raw = eventsBox.get(key);

              if (raw is Map) {
                final event = Map<String, dynamic>.from(raw);
                event['_key'] = key;
                events.add(event);
              }
            }

            events.sort(
              (a, b) => (a['name'] as String? ?? '')
                  .toLowerCase()
                  .compareTo((b['name'] as String? ?? '').toLowerCase()),
            );

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      'Eventos',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nenhum evento criado.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: events.map((event) {
                          final id =
                              (event['id'] ?? event['_key']).toString();

                          return CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              event['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: selectedEventIds.contains(id),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  if (!selectedEventIds.contains(id)) {
                                    selectedEventIds.add(id);
                                  }
                                } else {
                                  selectedEventIds.remove(id);
                                }
                              });

                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Concluído'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _loadCategories() {
    final set = LinkedHashSet<String>();
    set.add('(Sem categoria)');

    for (final value in categoriesBox.values) {
      if (value is String && value.trim().isNotEmpty) {
        set.add(value.trim());
      }
    }

    catOptions = set.toList();

    if (!catOptions.contains(selectedCategory)) {
      selectedCategory = '(Sem categoria)';
    }
  }

  void _rebuildFilteredCards() {
    if (selectedPaymentMethod == 'Crédito' ||
        selectedPaymentMethod == 'Débito') {
      final cards = widget.availableCards();

      filteredCards = cards
          .where((card) => card['type'] == selectedPaymentMethod)
          .toList();

      if (selectedCardKey != null &&
          !filteredCards.any((card) => card['_key'] == selectedCardKey)) {
        selectedCardKey = null;
        selectedCardName = null;
        selectedCardType = null;
      }
    } else {
      filteredCards = [];
      selectedCardKey = null;
      selectedCardName = null;
      selectedCardType = null;
    }
  }

  double _extractAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9,.\s]'), ' ');
    final match = RegExp(r'(\d+([.,]\d{1,2})?)').firstMatch(cleaned);

    if (match == null) return 0.0;

    final raw = match.group(0)!.replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return names[month - 1];
  }

  DateTime _addMonthsClamped(DateTime base, int monthsToAdd) {
    final rawMonth = base.month - 1 + monthsToAdd;
    final year = base.year + (rawMonth ~/ 12);
    final month = (rawMonth % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = base.day <= lastDay ? base.day : lastDay;

    return DateTime(
      year,
      month,
      day,
      base.hour,
      base.minute,
      base.second,
      base.millisecond,
      base.microsecond,
    );
  }

  DateTime _installmentDueDate(
    DateTime base,
    int monthsToAdd,
    String? paymentMethod,
    String? cardKey,
  ) {
    try {
      final target = _addMonthsClamped(base, monthsToAdd);

      if (paymentMethod == 'Crédito' && cardKey != null) {
        final cardData = cardsBox.get(cardKey);

        if (cardData is Map && cardData['closingDay'] != null) {
          final closingDay = cardData['closingDay'] is int
              ? cardData['closingDay'] as int
              : int.tryParse(cardData['closingDay']?.toString() ?? '') ??
                  base.day;

          if (monthsToAdd == 0) {
            return base;
          }

          final lastDay = DateTime(
            target.year,
            target.month + 1,
            0,
          ).day;

          final day = closingDay <= lastDay ? closingDay : lastDay;

          return DateTime(
            target.year,
            target.month,
            day,
            base.hour,
            base.minute,
            base.second,
            base.millisecond,
            base.microsecond,
          );
        }
      }

      return target;
    } catch (_) {
      return _addMonthsClamped(base, monthsToAdd);
    }
  }

  double _installmentAmount(double total, int count, int index) {
    if (count <= 1) return total;

    final base = double.parse((total / count).toStringAsFixed(2));

    if (index < count - 1) {
      return base;
    }

    final previous = base * (count - 1);

    return double.parse((total - previous).toStringAsFixed(2));
  }

  Future<String?> _promptNewCategory() async {
    String input = '';

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nova categoria'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: Restaurante',
            ),
            onChanged: (value) {
              input = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, input.trim());
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRecord() async {
    final title = titleCtrl.text.trim().isEmpty
        ? (isIncomeSelected ? 'Receita' : 'Despesa')
        : titleCtrl.text.trim();

    final typedAmount = double.tryParse(
      amountCtrl.text.trim().replaceAll(',', '.'),
    );

    final totalAmount = typedAmount ?? _extractAmount(title);

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido')),
      );
      return;
    }

    final parsedInstallments = int.tryParse(installmentCtrl.text.trim());

    final count = parsedInstallments == null || parsedInstallments < 1
        ? 1
        : parsedInstallments;

    final categoryValue = isIncomeSelected
        ? 'Receita'
        : selectedCategory == '(Sem categoria)'
            ? ''
            : selectedCategory;

    final timestampBase = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (isEditing) {
      final item = {
        'title': title,
        'module': 'Finanças',
        'timestamp': timestampBase.toIso8601String(),
        'isDone': false,
        'amount': totalAmount,
        'category': categoryValue,
        'installmentTotal': count,
        'installmentNumber': widget.existing?['installmentNumber'],
        'installmentGroupId': widget.existing?['installmentGroupId'],
        'originalAmount': widget.existing?['originalAmount'] ?? totalAmount,
        'paymentMethod': selectedPaymentMethod,
        'isIncome': isIncomeSelected,
        'cardId': selectedCardKey,
        'cardName': selectedCardName,
        'cardType': selectedCardType,
        'isSubscription': isSubscription,
        'eventIds': List<String>.from(selectedEventIds),
      };

      await box.put(widget.recordKey, item);
    } else if (count <= 1) {
      final item = {
        'title': title,
        'module': 'Finanças',
        'timestamp': timestampBase.toIso8601String(),
        'isDone': false,
        'amount': totalAmount,
        'category': categoryValue,
        'paymentMethod': selectedPaymentMethod,
        'isIncome': isIncomeSelected,
        'cardId': selectedCardKey,
        'cardName': selectedCardName,
        'cardType': selectedCardType,
        'isSubscription': isSubscription,
        'eventIds': List<String>.from(selectedEventIds),
      };

      if (!isSubscription) {
        await box.add(item);
      } else {
        final seriesId = 'sub_${DateTime.now().millisecondsSinceEpoch}';

        final masterTitle =
            '$title - ${_monthName(timestampBase.month)}/${timestampBase.year}';

        final masterKey = await box.add({
          ...item,
          'title': masterTitle,
          '_seriesId': seriesId,
          '_seriesMasterKey': null,
          '_seriesIndex': 0,
        });

        try {
          final masterRaw = Map<String, dynamic>.from(
            box.get(masterKey) as Map,
          );

          masterRaw['_seriesMasterKey'] = masterKey;
          await box.put(masterKey, masterRaw);
        } catch (_) {}

        final startMonth = timestampBase.month;
        int index = 1;

        for (int month = startMonth + 1; month <= 12; month++) {
          final monthsToAdd = month - startMonth;
          final dueDate = _addMonthsClamped(timestampBase, monthsToAdd);

          await box.add({
            ...item,
            'title':
                '$title - ${_monthName(dueDate.month)}/${dueDate.year}',
            'timestamp': dueDate.toIso8601String(),
            '_seriesId': seriesId,
            '_seriesMasterKey': masterKey,
            '_seriesIndex': index,
          });

          index++;
        }
      }
    } else {
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();

      for (int index = 0; index < count; index++) {
        final dueDate = _installmentDueDate(
          timestampBase,
          index,
          selectedPaymentMethod,
          selectedCardKey,
        );

        final installmentAmount = _installmentAmount(
          totalAmount,
          count,
          index,
        );

        await box.add({
          'title': '$title (${index + 1}/$count)',
          'module': 'Finanças',
          'timestamp': dueDate.toIso8601String(),
          'isDone': false,
          'amount': installmentAmount,
          'category': categoryValue,
          'installmentTotal': count,
          'installmentNumber': index + 1,
          'installmentGroupId': groupId,
          'originalAmount': totalAmount,
          'paymentMethod': selectedPaymentMethod,
          'isIncome': isIncomeSelected,
          'cardId': selectedCardKey,
          'cardName': selectedCardName,
          'cardType': selectedCardType,
          'isSubscription': isSubscription,
          'eventIds': List<String>.from(selectedEventIds),
        });
      }
    }

    widget.onSaved?.call();

    if (!widget.embedded && mounted) {
      Navigator.of(context).pop();
    }
  }

  static const List<String> _incomeWords = [
    'recebi',
    'recebido',
    'ganhei',
    'ganho',
    'entrou',
    'vendi',
    'salario',
    'deposito',
    'rendimento',
    'reembolso',
  ];

  String _stripAccents(String input) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ç': 'c',
      'ñ': 'n',
    };

    final buffer = StringBuffer();

    for (final char in input.toLowerCase().split('')) {
      buffer.write(accents[char] ?? char);
    }

    return buffer.toString();
  }

  _ParseResult _parseQuickText(String raw) {
    final normalized = _stripAccents(raw);
    final words = normalized.split(RegExp(r'\s+'));

    final isIncome = _incomeWords.any(words.contains);

    return _ParseResult(
      isIncome: isIncome,
      amount: _parseAmountFromText(normalized),
      description: _extractDescription(raw),
      method: _detectMethod(words, isIncome),
    );
  }

  double? _parseAmountFromText(String normalized) {
    // Ignora números seguidos de "x" (ex.: "3x" = parcelas).
    final regex = RegExp(
      r'(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+,\d{1,2}|\d+\.\d{2}|\d+)(?!\s*x)',
    );

    final match = regex.firstMatch(normalized);
    if (match == null) return null;

    var raw = match.group(0)!;
    final hasComma = raw.contains(',');
    final hasDot = raw.contains('.');

    if (hasComma && hasDot) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      raw = raw.replaceAll(',', '.');
    } else if (hasDot) {
      final parts = raw.split('.');

      if (parts.last.length == 3) {
        raw = raw.replaceAll('.', '');
      }
    }

    final value = double.tryParse(raw);
    return (value != null && value > 0) ? value : null;
  }

  String? _detectMethod(List<String> words, bool isIncome) {
    if (words.contains('credito')) return isIncome ? null : 'Crédito';
    if (words.contains('debito')) return isIncome ? null : 'Débito';

    if (words.contains('pix')) {
      return isIncome ? 'PIX' : 'Dinheiro/Pix';
    }

    if (words.contains('dinheiro') || words.contains('especie')) {
      return isIncome ? 'Dinheiro' : 'Dinheiro/Pix';
    }

    if (words.contains('transferencia') ||
        words.contains('ted') ||
        words.contains('doc')) {
      return isIncome ? 'Transferência' : null;
    }

    // "No cartão" sem especificar → crédito.
    if (words.contains('cartao')) return isIncome ? null : 'Crédito';

    return null;
  }

  String? _extractDescription(String raw) {
    const verbs = {
      'gastei',
      'gasto',
      'paguei',
      'pago',
      'comprei',
      'compra',
      'compras',
      'custou',
      'custa',
      'recebi',
      'recebido',
      'ganhei',
      'ganho',
      'entrou',
      'vendi',
      'venda',
    };

    const currency = {'reais', 'real', 'r\$', 'rs'};

    const methodWords = {
      'credito',
      'debito',
      'pix',
      'dinheiro',
      'especie',
      'transferencia',
      'cartao',
      'ted',
      'doc',
    };

    const connectors = {
      'na',
      'no',
      'nas',
      'nos',
      'em',
      'por',
      'com',
      'do',
      'da',
      'dos',
      'das',
      'de',
      'para',
      'pra',
      'um',
      'uma',
      'ao',
      'a',
      'o',
      'as',
      'os',
      'e',
    };

    final numberRegex = RegExp(
      r'^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$|^\d+,\d{1,2}$|^\d+\.\d{2}$|^\d+$',
    );

    final tokens = raw.trim().split(RegExp(r'\s+'));
    final kept = <String>[];

    for (final token in tokens) {
      final norm = _stripAccents(token.toLowerCase());

      if (verbs.contains(norm) ||
          currency.contains(norm) ||
          methodWords.contains(norm) ||
          numberRegex.hasMatch(norm)) {
        continue;
      }

      kept.add(token);
    }

    while (kept.isNotEmpty &&
        connectors.contains(_stripAccents(kept.first.toLowerCase()))) {
      kept.removeAt(0);
    }

    while (kept.isNotEmpty &&
        connectors.contains(_stripAccents(kept.last.toLowerCase()))) {
      kept.removeLast();
    }

    if (kept.isEmpty) return null;

    final result = kept.join(' ').trim();

    if (result.isEmpty) return null;

    return result[0].toUpperCase() + result.substring(1);
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _applyParsedText(String rawText) {
    if (rawText.trim().isEmpty) {
      _typeManuallyEdited = false;
      _descriptionManuallyEdited = false;
      _methodManuallyEdited = false;
      _amountManuallyEdited = false;
      return;
    }

    final parsed = _parseQuickText(rawText);

    if (!_typeManuallyEdited && parsed.isIncome != isIncomeSelected) {
      isIncomeSelected = parsed.isIncome;

      selectedPaymentMethod = parsed.method ??
          (parsed.isIncome ? incomeMethods.first : paymentMethods.first);

      _methodManuallyEdited = false;
      _rebuildFilteredCards();
    } else if (!_methodManuallyEdited &&
        parsed.method != null &&
        parsed.method != selectedPaymentMethod) {
      selectedPaymentMethod = parsed.method!;
      _rebuildFilteredCards();
    }

    if (!_amountManuallyEdited && parsed.amount != null) {
      amountCtrl.text = _formatAmount(parsed.amount!);
    }

    if (!_descriptionManuallyEdited &&
        parsed.description != null &&
        parsed.description!.trim() != titleCtrl.text.trim()) {
      titleCtrl.text = parsed.description!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditing
        ? (existingIsIncome ? 'Editar receita' : 'Editar despesa')
        : 'Adicionar registro';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.embedded) ...[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 1 - Tipo
            DropdownButtonFormField<String>(
              value: isIncomeSelected ? 'Receita' : 'Despesa',
              items: const [
                DropdownMenuItem(
                  value: 'Despesa',
                  child: Text('Despesa'),
                ),
                DropdownMenuItem(
                  value: 'Receita',
                  child: Text('Receita'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _typeManuallyEdited = true;
                  isIncomeSelected = value == 'Receita';
                  selectedPaymentMethod = isIncomeSelected
                      ? incomeMethods.first
                      : paymentMethods.first;

                  if (isIncomeSelected) {
                    selectedCardKey = null;
                    selectedCardName = null;
                    selectedCardType = null;
                    filteredCards = [];
                  }
                });
              },
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),

            const SizedBox(height: 12),

            // 2 - Descrição
            TextField(
              controller: titleCtrl,
              onChanged: (_) {
                _descriptionManuallyEdited = true;
              },
              decoration: InputDecoration(
                labelText:
                    isIncomeSelected ? 'Descrição (opcional)' : 'Descrição',
              ),
            ),

            const SizedBox(height: 10),

            // 3 - Categoria (apenas despesas)
            if (!isIncomeSelected) ...[
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: [
                  const DropdownMenuItem(
                    value: '(Sem categoria)',
                    child: Text('(Sem categoria)'),
                  ),
                  ...catOptions
                      .where((category) => category != '(Sem categoria)')
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                  const DropdownMenuItem(
                    value: '__add_new__',
                    child: Text('Adicionar nova categoria...'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  if (value == '__add_new__') {
                    final newCategory = await _promptNewCategory();

                    if (newCategory == null ||
                        newCategory.trim().isEmpty) {
                      return;
                    }

                    final trimmed = newCategory.trim();
                    String? existingCategory;

                    for (final value in categoriesBox.values) {
                      if (value is String &&
                          value.trim().toLowerCase() ==
                              trimmed.toLowerCase()) {
                        existingCategory = value.trim();
                        break;
                      }
                    }

                    if (existingCategory == null) {
                      await categoriesBox.add(trimmed);
                    }

                    _loadCategories();

                    setState(() {
                      selectedCategory = existingCategory ?? trimmed;
                    });
                  } else {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),

              const SizedBox(height: 10),
            ],

            // 4 - Método de pagamento/recebimento
            DropdownButtonFormField<String>(
              value: selectedPaymentMethod,
              items: (isIncomeSelected ? incomeMethods : paymentMethods)
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _methodManuallyEdited = true;
                  selectedPaymentMethod = value ??
                      (isIncomeSelected
                          ? incomeMethods.first
                          : paymentMethods.first);

                  if (!isIncomeSelected &&
                      selectedPaymentMethod != 'Crédito') {
                    installmentCtrl.text = '1';
                  }

                  _rebuildFilteredCards();
                });
              },
              decoration: InputDecoration(
                labelText: isIncomeSelected
                    ? 'Método de recebimento'
                    : 'Método de pagamento',
              ),
            ),

            // 5 - Cartão (apenas despesas)
            if (!isIncomeSelected) ...[
              const SizedBox(height: 10),

              DropdownButtonFormField<String?>(
                value: selectedCardKey,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhum cartão'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '__add_new__',
                    child: Text('Adicionar novo cartão...'),
                  ),
                  ...filteredCards.map(
                    (card) => DropdownMenuItem<String?>(
                      value: card['_key'] as String,
                      child: Text('${card['name']} (${card['type']})'),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  if (value == '__add_new__') {
                    final newId = await widget.showCardForm(null);

                    if (newId == null) {
                      setState(() {});
                      return;
                    }

                    final card = cardsBox.get(newId);

                    if (card is Map) {
                      setState(() {
                        selectedCardKey = newId;
                        selectedCardName = card['name'] as String?;
                        selectedCardType = card['type'] as String?;
                        _rebuildFilteredCards();
                      });
                    }

                    return;
                  }

                  setState(() {
                    selectedCardKey = value;

                    if (value == null) {
                      selectedCardName = null;
                      selectedCardType = null;
                    } else {
                      final card = cardsBox.get(value);

                      if (card is Map) {
                        selectedCardName = card['name'] as String?;
                        selectedCardType = card['type'] as String?;
                      }
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Cartão (opcional)',
                ),
              ),

              const SizedBox(height: 10),
            ],

            // 6 - Valor total
            TextField(
              controller: amountCtrl,
              onChanged: (_) {
                _amountManuallyEdited = true;
              },
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor total',
                hintText: 'Ex: 600.00',
              ),
            ),

            if (!isIncomeSelected && selectedPaymentMethod == 'Crédito') ...[
              const SizedBox(height: 10),
              TextField(
                controller: installmentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de parcelas',
                  hintText: '1 = sem parcelamento',
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 7 - Eventos (opcional)
            _buildEventSelector(),

            const SizedBox(height: 10),

            // 8 - Mensal? (apenas despesas)
            if (!isIncomeSelected) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mensal?'),
                subtitle: const Text(
                  'Criar registros todo mês automaticamente',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Switch(
                  value: isSubscription,
                  onChanged: (value) {
                    setState(() {
                      isSubscription = value;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    isSubscription = !isSubscription;
                  });
                },
              ),

              const SizedBox(height: 10),
            ],

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
                        setState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/'
                      '${selectedDate.month.toString().padLeft(2, '0')}/'
                      '${selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
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

                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                          selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:'
                      '${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                if (!widget.embedded)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                if (!widget.embedded) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRecord,
                    child: Text(isEditing ? 'Salvar' : 'Criar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _ParseResult {
  const _ParseResult({
    required this.isIncome,
    this.amount,
    this.description,
    this.method,
  });

  final bool isIncome;
  final double? amount;
  final String? description;
  final String? method;
}