// finance_screen.dart

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/finance_charts.dart';

enum PeriodPreset { today, week, month, custom }
enum AdvancedPeriod { none, monthNamed, bimestre, trimestre, semestre, year }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final box = Hive.box('alfred_box');
  late Box categoriesBox;

  PeriodPreset _period = PeriodPreset.today;
  DateTimeRange? _customRange;
  String? _selectedCategory;
  String? _selectedCardType; // agora guarda NOME do cartão filtrado
  String _search = '';

  AdvancedPeriod _advanced = AdvancedPeriod.none;
  int? _advMonth;
  int? _advYear;
  int? _advBimesterStart;
  int? _advQuarter;
  int? _advSemester;

  String _dropdownValue = 'Hoje';
  String _selectedPeriodOption = 'Hoje';

  final List<String> paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];
  final List<String> incomeMethods = ['Transferência', 'PIX', 'Dinheiro'];

  bool _filtersExpanded = true;
  bool _summaryExpanded = true;

  @override
  void initState() {
    super.initState();
    categoriesBox = Hive.box('alfred_finance_categories');
    if (categoriesBox.isEmpty) {
      final defaults = ['Alimentação', 'Transporte', 'Casa', 'Lazer', 'Saúde', 'Outros'];
      for (var c in defaults) categoriesBox.add(c);
    }

    _selectedPeriodOption = _labelForPeriod();
    _dropdownValue = 'Hoje';
  }

  // ---------- Date helpers ----------
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTime _startOfMonth(int year, int month) => DateTime(year, month, 1);
  DateTime _endOfMonth(int year, int month) {
    final next = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return next.subtract(const Duration(milliseconds: 1));
  }

  DateTime _addMonthsClamped(DateTime base, int monthsToAdd) {
    final rawMonth = base.month - 1 + monthsToAdd;
    final year = base.year + (rawMonth ~/ 12);
    final month = (rawMonth % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = base.day <= lastDay ? base.day : lastDay;
    return DateTime(year, month, day, base.hour, base.minute, base.second, base.millisecond, base.microsecond);
  }

  DateTimeRange _rangeForPreset(PeriodPreset p) {
    if (_advanced != AdvancedPeriod.none) {
      final adv = _rangeForAdvanced();
      if (adv != null) return adv;
    }
    final now = DateTime.now();
    if (p == PeriodPreset.today) {
      return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    } else if (p == PeriodPreset.week) {
      final start = _startOfDay(now.subtract(const Duration(days: 6)));
      return DateTimeRange(start: start, end: _endOfDay(now));
    } else if (p == PeriodPreset.month) {
      final start = DateTime(now.year, now.month, 1);
      final nextMonth = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
      final end = nextMonth.subtract(const Duration(milliseconds: 1));
      return DateTimeRange(start: start, end: end);
    } else {
      return _customRange ?? DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    }
  }

  DateTimeRange? _rangeForAdvanced() {
    switch (_advanced) {
      case AdvancedPeriod.monthNamed:
        if (_advMonth == null || _advYear == null) return null;
        final start = _startOfMonth(_advYear!, _advMonth!);
        final end = _endOfMonth(_advYear!, _advMonth!);
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.bimestre:
        if (_advBimesterStart == null || _advYear == null) return null;
        final start = _startOfMonth(_advYear!, _advBimesterStart!);
        final end = _endOfMonth(_addMonthsClamped(start, 1).year, _addMonthsClamped(start, 1).month);
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.trimestre:
        if (_advQuarter == null || _advYear == null) return null;
        final startMonth = 1 + (_advQuarter! - 1) * 3;
        final start = _startOfMonth(_advYear!, startMonth);
        final end = _endOfMonth(_advYear!, startMonth + 2);
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.semestre:
        if (_advSemester == null || _advYear == null) return null;
        final startMonth = _advSemester == 1 ? 1 : 7;
        final start = _startOfMonth(_advYear!, startMonth);
        final end = _endOfMonth(_advYear!, startMonth + 5);
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.year:
        if (_advYear == null) return null;
        final start = DateTime(_advYear!, 1, 1);
        final end = DateTime(_advYear! + 1, 1, 1).subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.none:
      default:
        return null;
    }
  }

  // ---------- Utilities ----------
  double _extractAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9,.\s]'), ' ');
    final match = RegExp(r'(\d+([.,]\d{1,2})?)').firstMatch(cleaned);
    if (match == null) return 0.0;
    final raw = match.group(0)!.replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  String _normalizeCategory(dynamic cat) {
    final c = (cat as String?)?.trim() ?? '';
    return c.isEmpty ? '(Sem categoria)' : c;
  }

  // ---------- Atualização: escondendo categoria literal 'Receita' ----------
  List<String> _availableCategories() {
    final Set<String> s = {};
    for (var raw in box.values) {
      try {
        final item = Map<String, dynamic>.from(raw as Map);
        if ((item['module'] ?? '') != 'Finanças') continue;

        final cat = _normalizeCategory(item['category']);
        // Oculta a categoria literal "Receita" da lista de chips,
        // pois já temos o botão fixo "Receitas" no início
        if (cat != 'Receita') {
          s.add(cat);
        }
      } catch (_) {}
    }
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        // Evita adicionar "Receita" a partir das sugestões da box também
        if (t.isNotEmpty && t != 'Receita') s.add(t);
      }
    }
    s.add('(Sem categoria)');
    final list = s.toList()..sort();
    // Botões fixos de ação rápida no início
    return ['(Todas)', 'Receitas', 'Despesas'] + list;
  }

  // ---------- NOVO: lista de filtros baseada no NOME/DESCRIÇÃO do cartão ----------
  List<String> _availableCardFilters() {
    final types = <String>{'(Todos)', 'Sem cartão'};
    // pegar nomes a partir dos lançamentos
    for (var raw in box.values) {
      try {
        final item = Map<String, dynamic>.from(raw as Map);
        if ((item['module'] ?? '') != 'Finanças') continue;
        final cn = (item['cardName'] as String?)?.trim();
        if (cn != null && cn.isNotEmpty) {
          types.add(cn);
        } else {
          types.add('Sem cartão');
        }
      } catch (_) {}
    }
    // também incluir cartões cadastrados na box 'cards'
    for (var k in _cardsBox.keys) {
      try {
        final raw = _cardsBox.get(k);
        if (raw is Map) {
          final name = (raw['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) types.add(name);
        }
      } catch (_) {}
    }
    final list = types.toList();
    list.sort((a, b) {
      if (a == '(Todos)') return -1;
      if (b == '(Todos)') return 1;
      if (a == 'Sem cartão') return 1;
      if (b == 'Sem cartão') return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  List<Map<String, dynamic>> _filteredFinanceItems() {
    final range = _rangeForPreset(_period);
    final List<Map<String, dynamic>> items = [];

    for (var k in box.keys) {
      try {
        final raw = box.get(k);
        final item = Map<String, dynamic>.from(raw as Map);
        if ((item['module'] ?? '') != 'Finanças') continue;

        final tsValue = item['timestamp'];
        DateTime? ts;
        if (tsValue is int) {
          ts = DateTime.fromMillisecondsSinceEpoch(tsValue);
        } else if (tsValue is String) {
          ts = DateTime.tryParse(tsValue);
        } else if (tsValue is DateTime) {
          ts = tsValue;
        }

        if (ts == null) continue;
        if (ts.isBefore(range.start) || ts.isAfter(range.end)) continue;

        final category = _normalizeCategory(item['category']);
        final isIncome = item['isIncome'] == true;

        if (_selectedCategory == 'Receitas' && !isIncome) continue;
        if (_selectedCategory == 'Despesas' && isIncome) continue;

        if (_selectedCategory != null && _selectedCategory != '(Todas)' && _selectedCategory != 'Receitas' && _selectedCategory != 'Despesas' && category != _selectedCategory) continue;

        // FILTRO POR NOME DO CARTÃO (cardName)
        final cardName = (item['cardName'] as String?)?.trim();
        if (_selectedCardType != null && _selectedCardType != '(Todos)') {
          if (_selectedCardType == 'Sem cartão') {
            if (cardName != null && cardName.isNotEmpty) continue;
          } else {
            if (cardName != _selectedCardType) continue;
          }
        }

        final title = (item['title'] as String? ?? '').toLowerCase();
        if (_search.isNotEmpty && !title.contains(_search.toLowerCase())) continue;

        final copy = Map<String, dynamic>.from(item);
        copy['_key'] = k;
        copy['_ts'] = ts;
        items.add(copy);
      } catch (_) {}
    }

    items.sort((a, b) {
      final ta = a['_ts'] as DateTime;
      final tb = b['_ts'] as DateTime;
      return tb.compareTo(ta);
    });

    return items;
  }

  double _sumItems(List<Map<String, dynamic>> items) {
    double total = 0.0;
    for (var item in items) {
      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(item['title'] as String? ?? '');
      total += amt;
    }
    return total;
  }

  Map<String, double> _sumByPaymentMethod(List<Map<String, dynamic>> items) {
    final Map<String, double> sums = {for (var m in paymentMethods) m: 0.0};
    for (var item in items) {
      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(item['title'] as String? ?? '');
      final pm = (item['paymentMethod'] as String?) ?? 'Dinheiro/Pix';
      if (!sums.containsKey(pm)) sums[pm] = 0.0;
      sums[pm] = sums[pm]! + amt;
    }
    return sums;
  }

  double _sumIncomes(List<Map<String, dynamic>> items) {
    double total = 0.0;
    for (var item in items) {
      final isIncome = item['isIncome'] == true;
      if (!isIncome) continue;
      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(item['title'] as String? ?? '');
      total += amt;
    }
    return total;
  }

  double _sumExpenses(List<Map<String, dynamic>> items) {
    double total = 0.0;
    for (var item in items) {
      final isIncome = item['isIncome'] == true;
      if (isIncome) continue;
      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(item['title'] as String? ?? '');
      total += amt;
    }
    return total;
  }

  String _generateCsv(List<Map<String, dynamic>> items) {
    final sb = StringBuffer();
    sb.writeln('timestamp,description,category,amount,payment_method,installment_number,installment_total,group_id,is_income,card_id,card_name,card_type');
    for (var it in items) {
      final ts = it['timestamp'] as String? ?? '';
      final title = (it['title'] as String?)?.replaceAll('"', '""') ?? '';
      final cat = _normalizeCategory(it['category']).replaceAll('"', '""');
      final amt = (it['amount'] is num) ? it['amount'].toString() : _extractAmount(title).toStringAsFixed(2);
      final pm = (it['paymentMethod'] as String?)?.replaceAll('"', '""') ?? '';
      final instNumber = (it['installmentNumber'] ?? '').toString();
      final instTotal = (it['installmentTotal'] ?? '').toString();
      final groupId = (it['installmentGroupId'] ?? '').toString();
      final isIncome = (it['isIncome'] == true) ? '1' : '0';
      final cardId = (it['cardId'] ?? '').toString();
      final cardName = (it['cardName'] ?? '').toString().replaceAll('"', '""');
      final cardType = (it['cardType'] ?? '').toString();
      sb.writeln('"$ts","$title","$cat",$amt,"$pm",$instNumber,$instTotal,"$groupId",$isIncome,"$cardId","$cardName","$cardType"');
    }
    return sb.toString();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _customRange = DateTimeRange(start: _startOfDay(picked.start), end: _endOfDay(picked.end));
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  String _labelForPeriod() {
    if (_advanced != AdvancedPeriod.none) {
      switch (_advanced) {
        case AdvancedPeriod.monthNamed:
          if (_advMonth != null && _advYear != null) return 'Mês: ${_monthName(_advMonth!)} ${_advYear!}';
          return 'Escolher mês';
        case AdvancedPeriod.bimestre:
          if (_advBimesterStart != null && _advYear != null) {
            final endMonth = _addMonthsClamped(DateTime(_advYear!, _advBimesterStart!), 1).month;
            return 'Bimestre: ${_monthName(_advBimesterStart!)} / ${_monthName(endMonth)} ${_advYear!}';
          }
          return 'Escolher bimestre';
        case AdvancedPeriod.trimestre:
          if (_advQuarter != null && _advYear != null) return 'Trimestre: T${_advQuarter!} ${_advYear!}';
          return 'Escolher trimestre';
        case AdvancedPeriod.semestre:
          if (_advSemester != null && _advYear != null) return 'Semestre: S${_advSemester!} ${_advYear!}';
          return 'Escolher semestre';
        case AdvancedPeriod.year:
          if (_advYear != null) return 'Ano: ${_advYear!}';
          return 'Escolher ano';
        default:
          return 'Avançado';
      }
    }
    if (_period == PeriodPreset.custom && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return '${s.day}/${s.month}/${s.year} — ${e.day}/${e.month}/${e.year}';
    }
    if (_period == PeriodPreset.today) return 'Hoje';
    if (_period == PeriodPreset.week) return 'Últimos 7 dias';
    if (_period == PeriodPreset.month) return 'Mês atual';
    return 'Período';
  }

  String _monthName(int m) {
    const names = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return names[m - 1];
  }

  String _formatDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} $hh:$mm';
  }

  // ---------- Advanced pickers ----------
  Future<void> _pickAdvancedOption(AdvancedPeriod sel) async {
    setState(() {
      _advanced = sel;
    });

    switch (sel) {
      case AdvancedPeriod.monthNamed:
        await _pickMonthNamed();
        break;
      case AdvancedPeriod.bimestre:
        await _pickBimester();
        break;
      case AdvancedPeriod.trimestre:
        await _pickQuarter();
        break;
      case AdvancedPeriod.semestre:
        await _pickSemester();
        break;
      case AdvancedPeriod.year:
        await _pickYear();
        break;
      case AdvancedPeriod.none:
        setState(() {
          _customRange = null;
          _period = PeriodPreset.today;
        });
        break;
    }

    setState(() {
      _selectedPeriodOption = _labelForPeriod();
    });
  }

  Future<void> _pickMonthNamed() async {
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    final res = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher mês e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    return ChoiceChip(
                      label: Text(_monthName(m)),
                      selected: month == m,
                      onSelected: (_) => setD(() => month = m),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: year.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ano'),
                      onChanged: (v) {
                        final y = int.tryParse(v);
                        if (y != null) setD(() => year = y);
                      },
                    ),
                  ),
                ]),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, {'year': year, 'month': month}), child: const Text('OK')),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        _advYear = res['year'];
        _advMonth = res['month'];
        _customRange = _rangeForAdvanced();
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.monthNamed;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  Future<void> _pickBimester() async {
    int year = DateTime.now().year;
    int start = 1;
    final res = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher bimestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(
                spacing: 6,
                children: [1, 3, 5, 7, 9, 11]
                    .map((m) => ChoiceChip(
                          label: Text('${_monthName(m)}/${_monthName(_addMonthsClamped(DateTime(0, m, 1), 1).month)}'),
                          selected: start == m,
                          onSelected: (_) => setD(() => start = m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: year.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ano'),
                onChanged: (v) {
                  final y = int.tryParse(v);
                  if (y != null) setD(() => year = y);
                },
              ),
            ]);
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, {'year': year, 'start': start}), child: const Text('OK')),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        _advYear = res['year'];
        _advBimesterStart = res['start'];
        _customRange = _rangeForAdvanced();
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.bimestre;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  Future<void> _pickQuarter() async {
    int year = DateTime.now().year;
    int quarter = 1;
    final res = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher trimestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [1, 2, 3, 4].map((q) {
                return ChoiceChip(label: Text('T$q'), selected: quarter == q, onSelected: (_) => setD(() => quarter = q));
              }).toList()),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: year.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ano'),
                onChanged: (v) {
                  final y = int.tryParse(v);
                  if (y != null) setD(() => year = y);
                },
              ),
            ]);
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, {'year': year, 'quarter': quarter}), child: const Text('OK')),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        _advYear = res['year'];
        _advQuarter = res['quarter'];
        _customRange = _rangeForAdvanced();
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.trimestre;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  Future<void> _pickSemester() async {
    int year = DateTime.now().year;
    int sem = 1;
    final res = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher semestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [1, 2].map((s) {
                return ChoiceChip(label: Text('S$s'), selected: sem == s, onSelected: (_) => setD(() => sem = s));
              }).toList()),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: year.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ano'),
                onChanged: (v) {
                  final y = int.tryParse(v);
                  if (y != null) setD(() => year = y);
                },
              ),
            ]);
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, {'year': year, 'sem': sem}), child: const Text('OK')),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        _advYear = res['year'];
        _advSemester = res['sem'];
        _customRange = _rangeForAdvanced();
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.semestre;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  Future<void> _pickYear() async {
    int year = DateTime.now().year;
    final res = await showDialog<int>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher ano'),
          content: TextFormField(
            initialValue: year.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ano'),
            onChanged: (v) {
              final y = int.tryParse(v);
              if (y != null) year = y;
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, year), child: const Text('OK')),
          ],
        );
      },
    );

    if (res != null) {
      setState(() {
        _advYear = res;
        _customRange = _rangeForAdvanced();
        _period = PeriodPreset.custom;
        _advanced = AdvancedPeriod.year;
        _selectedPeriodOption = _labelForPeriod();
      });
    } else {
      setState(() {
        _advanced = AdvancedPeriod.none;
        _selectedPeriodOption = _labelForPeriod();
      });
    }
  }

  // ---------- Installment & group helpers ----------
  double _installmentAmount(double total, int count, int index) {
    if (count <= 1) return total;
    final base = double.parse((total / count).toStringAsFixed(2));
    if (index < count - 1) return base;
    final previous = base * (count - 1);
    return double.parse((total - previous).toStringAsFixed(2));
  }

  List<Map<String, dynamic>> _getGroupItems(String groupId) {
    final List<Map<String, dynamic>> items = [];
    for (var k in box.keys) {
      try {
        final raw = box.get(k);
        final item = Map<String, dynamic>.from(raw as Map);
        if ((item['installmentGroupId'] ?? '') == groupId) {
          final copy = Map<String, dynamic>.from(item);
          copy['_key'] = k;
          items.add(copy);
        }
      } catch (_) {}
    }
    items.sort((a, b) {
      final na = (a['installmentNumber'] ?? 0) as int;
      final nb = (b['installmentNumber'] ?? 0) as int;
      return na.compareTo(nb);
    });
    return items;
  }

  Future<void> _deleteSeries(String groupId) async {
    final groupItems = _getGroupItems(groupId);
    if (groupItems.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir série inteira?'),
        content: Text('Tem certeza que deseja excluir ${groupItems.length} parcelas desta série? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) {
      for (var it in groupItems) {
        final k = it['_key'];
        if (k != null) box.delete(k);
      }
      if (mounted) setState(() {});
    }
  }

  // Helpers — obtenha a box 'cards' e lista de cartões
  Box get _cardsBox => Hive.box('cards');

  List<Map<String, dynamic>> _availableCards() {
    final out = <Map<String, dynamic>>[];
    for (var key in _cardsBox.keys) {
      final raw = _cardsBox.get(key);
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['_key'] = key; // chave Hive (útil para editar/excluir)
        out.add(m);
      }
    }
    // ordenar por name
    out.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return out;
  }

  // ---------- Cards UI: gerenciar e adicionar/editar (métodos dentro do estado) ----------
  Future<void> _showManageCards() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          final cards = _availableCards();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Cartões'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        await _showAddOrEditCard(null);
                        setSt(() {});
                      },
                    ),
                  ),
                  const Divider(),
                  if (cards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum cartão cadastrado. Toque + para criar.'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final c = cards[idx];
                          final type = (c['type'] ?? '') as String;
                          final closingDay = c['closingDay'];
                          final subtitle = type == 'Crédito' && closingDay != null ? '$type • Dia de virada: $closingDay' : type;
                          return ListTile(
                            title: Text('${c['name']}'),
                            subtitle: Text(subtitle),
                            leading: Icon(type == 'Crédito' ? Icons.credit_card : Icons.payment),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await _showAddOrEditCard(c['_key']);
                                    setSt(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    showDialog(
                                      context: ctx,
                                      builder: (dctx) => AlertDialog(
                                        title: const Text('Confirmar exclusão'),
                                        content: Text('Excluir "${c['name']}"? Isso não removerá lançamentos já vinculados.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancelar')),
                                          TextButton(
                                            onPressed: () {
                                              _cardsBox.delete(c['_key']);
                                              Navigator.pop(dctx);
                                              setSt(() {});
                                            },
                                            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // Retorna id do cartão criado/editado (ou null)
  Future<String?> _showAddOrEditCard(dynamic hiveKey) async {
    final cardsBox = _cardsBox;

    final nameCtrl = TextEditingController();
    String type = 'Crédito';
    int closingDay = 1; // default for crédito

    if (hiveKey != null) {
      final existing = Map<String, dynamic>.from(cardsBox.get(hiveKey) as Map);
      nameCtrl.text = (existing['name'] ?? '') as String;
      type = (existing['type'] ?? 'Crédito') as String;
      // existing closingDay may be null for Débito
      closingDay = (existing['closingDay'] is int) ? (existing['closingDay'] as int) : 1;
    }

    // retornará o id criado/atualizado (ou null se cancelar)
    return await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (bctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(bctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hiveKey == null ? 'Novo cartão' : 'Editar cartão',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nome do cartão'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'Crédito', child: Text('Crédito')),
                        DropdownMenuItem(value: 'Débito', child: Text('Débito')),
                      ],
                      onChanged: (v) {
                        setModal(() {
                          type = v ?? 'Crédito';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 12),
                    if (type == 'Crédito') ...[
                      DropdownButtonFormField<int>(
                        value: closingDay,
                        items: List.generate(31, (i) => i + 1).map((d) {
                          return DropdownMenuItem(value: d, child: Text(d.toString()));
                        }).toList(),
                        onChanged: (v) {
                          setModal(() {
                            closingDay = v ?? 1;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Dia de virada do ciclo'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (type == 'Débito') const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: Text(hiveKey == null ? 'Criar' : 'Salvar'),
                        onPressed: () {
                          final nm = nameCtrl.text.trim();
                          if (nm.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Informe o nome do cartão')),
                            );
                            return;
                          }

                          final id = hiveKey ?? DateTime.now().millisecondsSinceEpoch.toString();
                          final card = {
                            'id': id,
                            'name': nm,
                            'type': type,
                            // se for débito não salvamos dia de virada
                            'closingDay': type == 'Crédito' ? closingDay : null,
                          };

                          cardsBox.put(id, card);
                          // fecha o modal retornando o id
                          Navigator.of(bctx).pop(id);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showParcelOptions(BuildContext context, dynamic key, Map<String, dynamic> existing) {
    final groupId = existing['installmentGroupId'] as String?;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar apenas esta parcela'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddOrEditExpense(context, key: key, existing: existing);
              },
            ),
            if (groupId != null && groupId.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Editar série inteira'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditSeries(context, groupId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Excluir série inteira'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteSeries(groupId);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Excluir apenas esta parcela'),
              onTap: () {
                Navigator.pop(ctx);
                if (key != null) box.delete(key);
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(ctx),
            ),
          ]),
        );
      },
    );
  }

  String _baseTitleFromParcelTitle(String title) {
    return title.replaceAll(RegExp(r'\s*\(\d+/\d+\)\s*$'), '').trim();
  }

  Future<String?> _promptNewCategory(BuildContext ctx) async {
    String input = '';
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(autofocus: true, decoration: const InputDecoration(hintText: 'Ex: Restaurante'), onChanged: (v) => input = v),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, input.trim()), child: const Text('Adicionar')),
        ],
      ),
    );
  }

  // ---------- Edit series (modificada) ----------
  void _showEditSeries(BuildContext context, String groupId) {
    final groupItems = _getGroupItems(groupId);
    if (groupItems.isEmpty) return;

    final first = groupItems.first;
    final originalAmount = (first['originalAmount'] is num) ? (first['originalAmount'] as num).toDouble() : null;
    final currentTotal = originalAmount ?? groupItems.fold<double>(0.0, (prev, it) => prev + ((it['amount'] is num) ? (it['amount'] as num).toDouble() : _extractAmount(it['title'] as String? ?? '')));
    final currentInstallments = (first['installmentTotal'] is int) ? first['installmentTotal'] as int : (groupItems.length);
    final firstTs = DateTime.tryParse(first['timestamp'] as String? ?? '') ?? DateTime.now();
    final baseTitle = _baseTitleFromParcelTitle(first['title'] as String? ?? '');
    final currentCategory = _normalizeCategory(first['category']);
    final currentPaymentMethod = (first['paymentMethod'] as String?) ?? paymentMethods.first;
    final isIncome = first['isIncome'] == true;

    final titleCtrl = TextEditingController(text: baseTitle);
    final amountCtrl = TextEditingController(text: currentTotal.toStringAsFixed(2));
    final installmentCtrl = TextEditingController(text: currentInstallments.toString());
    DateTime selectedDate = firstTs;
    TimeOfDay selectedTime = TimeOfDay(hour: firstTs.hour, minute: firstTs.minute);
    String selectedCategory = currentCategory == '(Sem categoria)' ? '(Sem categoria)' : currentCategory;
    String selectedPaymentMethod = currentPaymentMethod;

    // card selection initial state (by key)
    String? selectedCardKey = first['cardId'] as String?;
    String? selectedCardName = first['cardName'] as String?;
    String? selectedCardType = first['cardType'] as String?;

    final LinkedHashSet<String> catSet = LinkedHashSet<String>();
    catSet.add('(Sem categoria)');
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) catSet.add(t);
      }
    }
    List<String> catOptions = catSet.toList();

    if (!catOptions.contains(selectedCategory)) {
      selectedCategory = '(Sem categoria)';
    }

    final cards = _availableCards();
    List<Map<String, dynamic>> filteredCards = [];
    void _rebuildFilteredCards(StateSetter setModal) {
      if (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito') {
        filteredCards = cards.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
        // if currently selected card key is not in filtered, clear selection
        if (selectedCardKey != null && !filteredCards.any((c) => c['_key'] == selectedCardKey)) {
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
      setModal(() {}); // atualiza modal
    }

    // inicializa filteredCards
    if (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito') {
      filteredCards = cards.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const Text('Editar série de parcelas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Descrição base')),
                const SizedBox(height: 8),
                if (!isIncome) ...[
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: [
                      const DropdownMenuItem(value: '(Sem categoria)', child: Text('(Sem categoria)')),
                      ...catOptions.where((c) => c != '(Sem categoria)').map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Adicionar nova categoria...')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      if (v == '__add_new__') {
                        final newCat = await _promptNewCategory(ctx);
                        if (newCat != null && newCat.trim().isNotEmpty) {
                          final newCatTrim = newCat.trim();
                          String? storedMatch;
                          for (var val in categoriesBox.values) {
                            if (val is String && val.trim().toLowerCase() == newCatTrim.toLowerCase()) {
                              storedMatch = val.trim();
                              break;
                            }
                          }
                          if (storedMatch == null) {
                            categoriesBox.add(newCatTrim);
                          }
                          final stored = storedMatch ?? newCatTrim;

                          final LinkedHashSet<String> updatedSet = LinkedHashSet<String>();
                          updatedSet.add('(Sem categoria)');
                          for (var c in categoriesBox.values) {
                            if (c is String) {
                              final t = c.trim();
                              if (t.isNotEmpty) updatedSet.add(t);
                            }
                          }

                          setModal(() {
                            catOptions = updatedSet.toList();
                            selectedCategory = stored;
                          });
                        }
                      } else {
                        setModal(() {
                          selectedCategory = v;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                  const SizedBox(height: 8),

                  // --- Método de pagamento (AGORA aqui) ---
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModal(() {
                      selectedPaymentMethod = v ?? paymentMethods.first;
                      if (selectedPaymentMethod != 'Crédito') {
                        installmentCtrl.text = '1';
                      }
                      // rebuild filteredCards conforme novo método
                      _rebuildFilteredCards(setModal);
                    }),
                    decoration: const InputDecoration(labelText: 'Método de pagamento'),
                  ),
                  const SizedBox(height: 8),

                  // --- Card dropdown (AGORA: sempre renderiza, mesmo se filteredCards vazio) ---
                  DropdownButtonFormField<String?>(
                    value: selectedCardKey,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Nenhum cartão')),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Adicionar novo cartão...')),
                      ...filteredCards.map((c) => DropdownMenuItem(value: c['_key'] as String, child: Text('${c['name']} (${c['type']})'))),
                    ],
                    onChanged: (v) async {
                      if (v == '__add_new__') {
                        final newId = await _showAddOrEditCard(null);
                        final updated = _availableCards();
                        filteredCards = updated.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
                        if (newId != null) {
                          final c = _cardsBox.get(newId) as Map?;
                          setModal(() {
                            selectedCardKey = newId;
                            selectedCardName = c != null ? (c['name'] as String?) : null;
                            selectedCardType = c != null ? (c['type'] as String?) : null;
                          });
                        } else {
                          setModal(() {}); // força redraw se usuário cancelou
                        }
                      } else {
                        setModal(() {
                          selectedCardKey = v;
                          if (v != null) {
                            final c = _cardsBox.get(v) as Map;
                            selectedCardName = c['name'] as String?;
                            selectedCardType = c['type'] as String?;
                            // manter coerência: se cardType difere do método (improvável), sincroniza
                            if (selectedCardType != selectedPaymentMethod && (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito')) {
                              selectedPaymentMethod = selectedCardType ?? selectedPaymentMethod;
                            }
                          } else {
                            selectedCardName = null;
                            selectedCardType = null;
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Cartão (opcional)'),
                  ),
                  const SizedBox(height: 8),

                  TextField(controller: amountCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total')),
                  const SizedBox(height: 8),
                  if (!isIncome && (selectedPaymentMethod == 'Crédito')) ...[
                    TextField(
                      controller: installmentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Número de parcelas'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: incomeMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModal(() => selectedPaymentMethod = v ?? incomeMethods.first),
                    decoration: const InputDecoration(labelText: 'Método de pagamento'),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) {
                          setModal(() {
                            selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute);
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatDate(selectedDate)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final titleBase = titleCtrl.text.trim().isEmpty ? (isIncome ? 'Receita' : 'Despesa') : titleCtrl.text.trim();
                        final totalAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? _extractAmount(titleBase);
                        final installmentCount = int.tryParse(installmentCtrl.text.trim()) ?? 1;
                        final count = installmentCount < 1 ? 1 : installmentCount;
                        final categoryValue = isIncome ? 'Receita' : (selectedCategory == '(Sem categoria)' ? '' : selectedCategory);
                        final timestampBase = selectedDate;

                        for (var it in groupItems) {
                          final k = it['_key'];
                          if (k != null) box.delete(k);
                        }

                        for (int i = 0; i < count; i++) {
                          final dueDate = _addMonthsClamped(timestampBase, i);
                          final installmentAmount = _installmentAmount(totalAmount, count, i);
                          final item = {
                            'title': '$titleBase (${i + 1}/$count)',
                            'module': 'Finanças',
                            'timestamp': dueDate.toIso8601String(),
                            'isDone': false,
                            'amount': installmentAmount,
                            'category': categoryValue,
                            'installmentTotal': count,
                            'installmentNumber': i + 1,
                            'installmentGroupId': groupId,
                            'originalAmount': totalAmount,
                            'paymentMethod': selectedPaymentMethod,
                            'isIncome': isIncome,
                            'cardId': first['cardId'] ?? null,
                            'cardName': first['cardName'] ?? null,
                            'cardType': first['cardType'] ?? null,
                          };
                          final newKey = '$groupId-${i + 1}-${dueDate.year}${dueDate.month}${dueDate.day}';
                          box.put(newKey, item);
                        }

                        Navigator.pop(ctx);
                        if (mounted) setState(() {});
                      },
                      child: const Text('Salvar série'),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
              ]),
            ),
          );
        });
      },
    );
  }

  // ---------- Add / Edit single expense (modificada) ----------
  void _showAddOrEditExpense(BuildContext context, {dynamic key, Map<String, dynamic>? existing}) {
    final bool isEditing = key != null;
    final bool existingIsIncome = existing != null && (existing['isIncome'] == true);

    final titleCtrl = TextEditingController(text: existing != null ? (existing['title'] as String? ?? '') : '');
    final amountCtrl = TextEditingController(text: existing != null ? ((existing['amount'] is num) ? existing['amount'].toString() : '') : '');
    final installmentCtrl = TextEditingController(text: existing != null && existing['installmentTotal'] != null ? existing['installmentTotal'].toString() : '1');
    final DateTime _baseTs = existing != null ? (DateTime.tryParse(existing['timestamp'] as String? ?? '') ?? DateTime.now()) : DateTime.now();
    DateTime selectedDate = _baseTs;
    TimeOfDay selectedTime = TimeOfDay(hour: _baseTs.hour, minute: _baseTs.minute);
    String selectedCategory = existing != null ? _normalizeCategory(existing['category']) : '(Sem categoria)';
    String selectedPaymentMethod = existing != null ? (existing['paymentMethod'] as String? ?? paymentMethods.first) : paymentMethods.first;
    bool isIncomeSelected = existingIsIncome;

    // Card selection initial state
    String? selectedCardKey = existing != null && existing['cardId'] != null ? existing['cardId'] as String? : null;
    String? selectedCardName = existing != null && existing['cardName'] != null ? existing['cardName'] as String? : null;
    String? selectedCardType = existing != null && existing['cardType'] != null ? existing['cardType'] as String? : null;
    if (selectedCardType != null) {
      // ensure payment method sync if card exists
      if (selectedCardType == 'Crédito') selectedPaymentMethod = 'Crédito';
      else if (selectedCardType == 'Débito') selectedPaymentMethod = 'Débito';
    }

    final LinkedHashSet<String> catSet = LinkedHashSet<String>();
    catSet.add('(Sem categoria)');
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) catSet.add(t);
      }
    }
    List<String> catOptions = catSet.toList();

    if (!catOptions.contains(selectedCategory)) {
      selectedCategory = '(Sem categoria)';
    }

    final cards = _availableCards();
    List<Map<String, dynamic>> filteredCards = [];
    void _rebuildFilteredCards(StateSetter setModal) {
      if (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito') {
        filteredCards = cards.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
        if (selectedCardKey != null && !filteredCards.any((c) => c['_key'] == selectedCardKey)) {
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

    // initialize filteredCards based on initial payment method
    if (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito') {
      filteredCards = cards.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                Text(isEditing ? (existingIsIncome ? 'Editar receita' : 'Editar despesa') : 'Adicionar registro', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: isIncomeSelected ? 'Receita' : 'Despesa',
                  items: const [
                    DropdownMenuItem(value: 'Despesa', child: Text('Despesa')),
                    DropdownMenuItem(value: 'Receita', child: Text('Receita')),
                  ],
                  onChanged: (v) => setModal(() {
                    isIncomeSelected = (v == 'Receita');
                    selectedPaymentMethod = isIncomeSelected ? incomeMethods.first : paymentMethods.first;
                    if (!isIncomeSelected && selectedCategory == '(Sem categoria)') selectedCategory = '(Sem categoria)';
                    // if switching to receita, clear card selection
                    if (isIncomeSelected) {
                      selectedCardKey = null;
                      selectedCardName = null;
                      selectedCardType = null;
                      filteredCards = [];
                    }
                  }),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),

                const SizedBox(height: 12),

                if (!isIncomeSelected) ...[
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: [
                      const DropdownMenuItem(value: '(Sem categoria)', child: Text('(Sem categoria)')),
                      ...catOptions.where((c) => c != '(Sem categoria)').map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Adicionar nova categoria...')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      if (v == '__add_new__') {
                        final newCat = await _promptNewCategory(ctx);
                        if (newCat != null && newCat.trim().isNotEmpty) {
                          final newCatTrim = newCat.trim();
                          String? storedMatch;
                          for (var val in categoriesBox.values) {
                            if (val is String && val.trim().toLowerCase() == newCatTrim.toLowerCase()) {
                              storedMatch = val.trim();
                              break;
                            }
                          }
                          if (storedMatch == null) {
                            categoriesBox.add(newCatTrim);
                          }
                          final stored = storedMatch ?? newCatTrim;

                          final LinkedHashSet<String> updatedSet = LinkedHashSet<String>();
                          updatedSet.add('(Sem categoria)');
                          for (var c in categoriesBox.values) {
                            if (c is String) {
                              final t = c.trim();
                              if (t.isNotEmpty) updatedSet.add(t);
                            }
                          }

                          setModal(() {
                            catOptions = updatedSet.toList();
                            selectedCategory = stored;
                          });
                        }
                      } else {
                        setModal(() {
                          selectedCategory = v;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                  const SizedBox(height: 10),

                  // --- Método de pagamento (AGORA depois da categoria) ---
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: (isIncomeSelected ? incomeMethods : paymentMethods).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModal(() {
                      selectedPaymentMethod = v ?? (isIncomeSelected ? incomeMethods.first : paymentMethods.first);
                      if (!isIncomeSelected && selectedPaymentMethod != 'Crédito') {
                        installmentCtrl.text = '1';
                      }
                      // rebuild filteredCards conforme seleção do método
                      if (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito') {
                        filteredCards = cards.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
                        // se o selectedCardKey não existe mais no filtro, limpe
                        if (selectedCardKey != null && !filteredCards.any((c) => c['_key'] == selectedCardKey)) {
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
                    }),
                    decoration: const InputDecoration(labelText: 'Método de pagamento'),
                  ),

                  const SizedBox(height: 10),

                  // --- Card dropdown (AGORA: sempre renderiza, inclui opção de adicionar) ---
                  DropdownButtonFormField<String?>(
                    value: selectedCardKey,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Nenhum cartão')),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Adicionar novo cartão...')),
                      ...filteredCards.map((c) => DropdownMenuItem(value: c['_key'] as String, child: Text('${c['name']} (${c['type']})'))),
                    ],
                    onChanged: (v) async {
                      if (v == '__add_new__') {
                        final newId = await _showAddOrEditCard(null);
                        final updated = _availableCards();
                        filteredCards = updated.where((c) => (c['type'] as String?) == selectedPaymentMethod).toList();
                        if (newId != null) {
                          final c = _cardsBox.get(newId) as Map?;
                          setModal(() {
                            selectedCardKey = newId;
                            selectedCardName = c != null ? (c['name'] as String?) : null;
                            selectedCardType = c != null ? (c['type'] as String?) : null;
                          });
                        } else {
                          setModal(() {});
                        }
                      } else {
                        setModal(() {
                          selectedCardKey = v;
                          if (v != null) {
                            final c = _cardsBox.get(v) as Map;
                            selectedCardName = c['name'] as String?;
                            selectedCardType = c['type'] as String?;
                            // garantir coerência entre método e tipo do cartão
                            if (selectedCardType != selectedPaymentMethod && (selectedPaymentMethod == 'Crédito' || selectedPaymentMethod == 'Débito')) {
                              selectedPaymentMethod = selectedCardType ?? selectedPaymentMethod;
                            }
                          } else {
                            selectedCardName = null;
                            selectedCardType = null;
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Cartão (opcional)'),
                  ),
                  const SizedBox(height: 10),

                  TextField(controller: amountCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total', hintText: 'Ex: 600.00')),
                  const SizedBox(height: 10),

                  if (!isIncomeSelected && (selectedPaymentMethod == 'Crédito')) ...[
                    TextField(
                      controller: installmentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número de parcelas',
                        hintText: '1 = sem parcelamento (apenas crédito)',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ] else ...[
                  // receita branch
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
                  const SizedBox(height: 10),
                  // método de recebimento (para receitas) — mantemos, mas sem cartões
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    items: incomeMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModal(() => selectedPaymentMethod = v ?? incomeMethods.first),
                    decoration: const InputDecoration(labelText: 'Método de recebimento'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: amountCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total', hintText: 'Ex: 600.00')),
                  const SizedBox(height: 10),
                ],

                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) {
                          setModal(() {
                            selectedDate = DateTime(picked.year, picked.month, picked.day, selectedTime.hour, selectedTime.minute);
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text('${selectedDate.day.toString().padLeft(2,'0')}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.year}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModal(() {
                            selectedTime = picked;
                            selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text('${selectedTime.hour.toString().padLeft(2,'0')}:${selectedTime.minute.toString().padLeft(2,'0')}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim().isEmpty ? (isIncomeSelected ? 'Receita' : 'Despesa') : titleCtrl.text.trim();
                        final totalAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? _extractAmount(title);
                        final installmentCount = int.tryParse(installmentCtrl.text.trim()) ?? 1;
                        final count = installmentCount < 1 ? 1 : installmentCount;
                        final categoryValue = isIncomeSelected ? 'Receita' : (selectedCategory == '(Sem categoria)' ? '' : selectedCategory);
                        final timestampBase = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);

                        if (isEditing) {
                          final item = {
                            'title': title,
                            'module': 'Finanças',
                            'timestamp': timestampBase.toIso8601String(),
                            'isDone': false,
                            'amount': totalAmount,
                            'category': categoryValue,
                            'installmentTotal': count,
                            'installmentNumber': existing?['installmentNumber'],
                            'installmentGroupId': existing?['installmentGroupId'],
                            'originalAmount': existing?['originalAmount'] ?? totalAmount,
                            'paymentMethod': selectedPaymentMethod,
                            'isIncome': isIncomeSelected,
                            'cardId': selectedCardKey,
                            'cardName': selectedCardName,
                            'cardType': selectedCardType,
                          };
                          box.put(key, item);
                        } else {
                          if (count <= 1) {
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
                            };
                            box.add(item);
                          } else {
                            final groupId = DateTime.now().millisecondsSinceEpoch.toString();
                            for (int i = 0; i < count; i++) {
                              final dueDate = _addMonthsClamped(timestampBase, i);
                              final installmentAmount = _installmentAmount(totalAmount, count, i);
                              final item = {
                                'title': '$title (${i + 1}/$count)',
                                'module': 'Finanças',
                                'timestamp': dueDate.toIso8601String(),
                                'isDone': false,
                                'amount': installmentAmount,
                                'category': categoryValue,
                                'installmentTotal': count,
                                'installmentNumber': i + 1,
                                'installmentGroupId': groupId,
                                'originalAmount': totalAmount,
                                'paymentMethod': selectedPaymentMethod,
                                'isIncome': isIncomeSelected,
                                'cardId': selectedCardKey,
                                'cardName': selectedCardName,
                                'cardType': selectedCardType,
                              };
                              box.add(item);
                            }
                          }
                        }

                        Navigator.pop(ctx);
                        if (mounted) setState(() {});
                      },
                      child: Text(isEditing ? 'Salvar' : 'Criar'),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
              ]),
            ),
          );
        });
      },
    );
  }

  // ---------- Categories management ----------
  int _dedupeCategories() {
    final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(categoriesBox.toMap());
    final Map<String, dynamic> seen = {};
    final List<dynamic> keysToDelete = [];

    for (var entry in map.entries) {
      final val = entry.value;
      if (val is! String) continue;
      final norm = val.trim().toLowerCase();
      if (seen.containsKey(norm)) {
        keysToDelete.add(entry.key);
      } else {
        seen[norm] = val.trim();
      }
    }

    for (var k in keysToDelete) {
      categoriesBox.delete(k);
    }

    return keysToDelete.length;
  }

  Future<void> _confirmAndDedupe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar duplicatas de categorias'),
        content: const Text('Isto irá remover categorias duplicadas (comparação sem diferenciar maiúsculas/minúsculas). Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Executar')),
        ],
      ),
    );

    if (confirmed == true) {
      final removed = _dedupeCategories();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dedupe concluído — $removed duplicata(s) removida(s).')));
    }
  }

  Future<void> _manageCategories() async {
    final newCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          final List<String> cats = [];
          for (var v in categoriesBox.values) {
            if (v is String && v.trim().isNotEmpty) cats.add(v.trim());
          }
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: const [Expanded(child: Text('Gerenciar categorias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return ListTile(
                      title: Text(c),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Excluir categoria'),
                              content: Text('Excluir "$c"? Esta ação remove apenas a categoria; itens existentes não são alterados.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final map = Map<dynamic, dynamic>.from(categoriesBox.toMap());
                            dynamic keyToRemove;
                            for (var e in map.entries) {
                              if (e.value is String && (e.value as String).trim() == c) {
                                keyToRemove = e.key;
                                break;
                              }
                            }
                            if (keyToRemove != null) {
                              categoriesBox.delete(keyToRemove);
                              setModal(() {}); // refresh modal UI
                              if (mounted) setState(() {}); // refresh main UI
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria "$c" excluída')));
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: TextField(controller: newCtrl, decoration: const InputDecoration(hintText: 'Nova categoria'))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final v = newCtrl.text.trim();
                      if (v.isEmpty) return;
                      bool exists = false;
                      for (var val in categoriesBox.values) {
                        if (val is String && val.trim().toLowerCase() == v.toLowerCase()) {
                          exists = true;
                          break;
                        }
                      }
                      if (!exists) {
                        categoriesBox.add(v);
                        newCtrl.clear();
                        setModal(() {});
                        if (mounted) setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria "$v" adicionada')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria "$v" já existe')));
                      }
                    },
                    child: const Text('Adicionar'),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          );
        });
      },
    );
  }

  // Escolhe ícone para chip de filtro de cartão
  IconData _cardFilterIcon(String name) {
    if (name == '(Todos)') return Icons.view_list;
    if (name == 'Sem cartão') return Icons.block;
    return Icons.credit_card;
  }

  @override
  Widget build(BuildContext context) {
    final availableCats = _availableCategories();
    final items = _filteredFinanceItems();
    final sumsByMethod = _sumByPaymentMethod(items);
    final totalIncomes = _sumIncomes(items);
    final totalExpenses = _sumExpenses(items);
    final net = totalIncomes - totalExpenses;

    final List<String> periodOptions = [
      'Hoje',
      'Semana',
      'Mês (escolher)',
      'Trimestre',
      'Semestre',
      'Ano',
      'Personalizado',
    ];

    final availableCardFilters = _availableCardFilters();

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Finanças'),
          const SizedBox(height: 2),
          Text(_labelForPeriod(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download),
            onPressed: () {
              final csv = _generateCsv(items);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('CSV gerado'),
                  content: SizedBox(width: double.maxFinite, child: SelectableText(csv)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csv));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiado para a área de transferência')));
                      },
                      child: const Text('Copiar CSV'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Gráficos',
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.92,
                  child: FinanceChartsModal(box: box),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dedupe') _confirmAndDedupe();
              if (v == 'manage') _manageCategories();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'manage', child: Text('Gerenciar categorias')),
              PopupMenuItem(value: 'dedupe', child: Text('Limpar duplicatas de categorias')),
            ],
          ),
          // manage cards quick access
          IconButton(
            tooltip: 'Cartões',
            icon: const Icon(Icons.credit_card),
            onPressed: () => _showManageCards(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditExpense(context),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            IconButton(
              icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more),
              tooltip: _filtersExpanded ? 'Ocultar filtros' : 'Mostrar filtros',
              onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            ),
            DropdownButton<String>(
              value: _dropdownValue,
              items: periodOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {
                  _dropdownValue = v;
                });

                if (v == 'Hoje') {
                  setState(() {
                    _period = PeriodPreset.today;
                    _advanced = AdvancedPeriod.none;
                    _customRange = null;
                    _selectedPeriodOption = _labelForPeriod();
                  });
                } else if (v == 'Semana') {
                  setState(() {
                    _period = PeriodPreset.week;
                    _advanced = AdvancedPeriod.none;
                    _customRange = null;
                    _selectedPeriodOption = _labelForPeriod();
                  });
                } else if (v == 'Mês (escolher)') {
                  await _pickMonthNamed();
                } else if (v == 'Trimestre') {
                  await _pickQuarter();
                } else if (v == 'Semestre') {
                  await _pickSemester();
                } else if (v == 'Ano') {
                  await _pickYear();
                } else if (v == 'Personalizado') {
                  await _pickCustomRange();
                } else {
                  setState(() {
                    _selectedPeriodOption = _labelForPeriod();
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _pickCustomRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(_labelForPeriod()),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Limpar filtros',
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _period = PeriodPreset.today;
                  _customRange = null;
                  _advanced = AdvancedPeriod.none;
                  _selectedCategory = null;
                  _selectedCardType = null; // limpa filtro de cartão
                  _search = '';
                  _selectedPeriodOption = _labelForPeriod();
                  _dropdownValue = 'Hoje';
                });
              },
            ),
          ]),
        ),

        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar descrição...'), onChanged: (v) => setState(() => _search = v)),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  children: availableCats.map((c) {
                    final isAll = c == '(Todas)';
                    final selected = (_selectedCategory ?? '(Todas)') == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = isAll ? null : c;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // --- Filtro por cartão (nome/descrição) com destaque de ícone ---
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: availableCardFilters.map((c) {
                    final isAll = c == '(Todos)';
                    final selected = (_selectedCardType ?? '(Todos)') == c;
                    final iconData = _cardFilterIcon(c);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(iconData, size: 18, color: selected ? Colors.white : Colors.grey[700]),
                        label: Text(c),
                        selected: selected,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        onSelected: (_) {
                          setState(() {
                            _selectedCardType = isAll ? null : c;
                          });
                        },
                        labelStyle: TextStyle(color: selected ? Colors.white : null),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _filtersExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
              children: [
                Expanded(child: Text('Resumo', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  icon: Icon(_summaryExpanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: _summaryExpanded ? 'Ocultar resumo' : 'Mostrar resumo',
                  onPressed: () => setState(() => _summaryExpanded = !_summaryExpanded),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Receitas', style: TextStyle(fontSize: 14)),
                        Text('R\$ ${totalIncomes.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Despesas', style: TextStyle(fontSize: 14)),
                        Text('R\$ ${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Saldo', style: TextStyle(fontSize: 14)),
                        Text('R\$ ${net.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: net >= 0 ? Colors.green[700] : Colors.red[700])),
                      ]),
                    ]),
                    const Divider(),
                    ...paymentMethods.map((m) {
                      final v = sumsByMethod[m] ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            _paymentMethodIcon(m),
                            const SizedBox(width: 8),
                            Text(m),
                          ]),
                          Text('R\$ ${v.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      );
                    }).toList(),
                  ]),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _summaryExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
          ]),
        ),

        const SizedBox(height: 6),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box b, _) {
              if (items.isEmpty) return Center(child: Text('Nenhum item encontrado para ${_labelForPeriod()}.'),);
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final title = item['title'] as String? ?? '';
                  final category = _normalizeCategory(item['category']);
                  final ts = item['_ts'] as DateTime;
                  final timeLabel = '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                  final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(title);
                  final key = item['_key'];
                  // ---------- Ajuste: mostra parcela somente quando os dois campos existem ----------
                  final instNum = (item['installmentNumber'] is int) ? item['installmentNumber'] as int : null;
                  final instTotal = (item['installmentTotal'] is int) ? item['installmentTotal'] as int : null;
                  final installmentInfo = (instNum != null && instTotal != null) ? 'Parcela ${instNum}/${instTotal}' : '';
                  final pm = (item['paymentMethod'] as String?) ?? '';
                  final isIncomeItem = item['isIncome'] == true;
                  final cardName = (item['cardName'] as String?) ?? '';

                  return Dismissible(
                    key: Key('$key-$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent, child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) {
                      if (key != null) b.delete(key);
                      if (mounted) setState(() {});
                    },
                    child: ListTile(
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(installmentInfo.isNotEmpty ? '$category • $installmentInfo' : category),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _paymentMethodIcon(pm),
                              const SizedBox(width: 6),
                              Flexible(child: Text(pm + (cardName.isNotEmpty ? ' • $cardName' : ''), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 12),
                              Text(timeLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${isIncomeItem ? '+' : ''}R\$ ${amt.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isIncomeItem ? Colors.green[700] : null),
                      ),
                      onTap: () {
                        _showParcelOptions(context, key, item);
                      },
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

  Widget _paymentMethodIcon(String method) {
    switch (method) {
      case 'Dinheiro/Pix':
      case 'Dinheiro':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'Débito':
        return const Icon(Icons.credit_card, size: 16, color: Colors.blue);
      case 'Crédito':
        return const Icon(Icons.payment, size: 16, color: Colors.deepPurple);
      case 'Transferência':
      case 'PIX':
        return const Icon(Icons.swap_horiz, size: 16, color: Colors.teal);
      default:
        return const SizedBox(width: 16, height: 16);
    }
  }
}