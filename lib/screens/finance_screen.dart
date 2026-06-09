import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:collection';

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
  String _search = '';

  // Advanced period state
  AdvancedPeriod _advanced = AdvancedPeriod.none;
  int? _advMonth; // 1..12
  int? _advYear;
  int? _advBimesterStart; // 1,3,5,7,9,11
  int? _advQuarter; // 1..4
  int? _advSemester; // 1..2

  // Dropdown control: fixed static value (must be one of periodOptions)
  String _dropdownValue = 'Hoje';
  // dynamic label shown beside the dropdown (can be "Mês: Jun 2026", etc.)
  String _selectedPeriodOption = 'Hoje';

  final List<String> paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];

  @override
  void initState() {
    super.initState();
    categoriesBox = Hive.box('alfred_finance_categories');
    if (categoriesBox.isEmpty) {
      final defaults = ['Alimentação', 'Transporte', 'Casa', 'Lazer', 'Saúde', 'Outros'];
      for (var c in defaults) categoriesBox.add(c);
    }

    // inicializa label inicial conforme estado
    _selectedPeriodOption = _labelForPeriod();
    _dropdownValue = 'Hoje';
  }

  // ---------- Datas e utilitários ----------
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

  // retorna intervalo para presets e advanced
  DateTimeRange _rangeForPreset(PeriodPreset p) {
    // se advanced ativo, usa ele
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
    final now = DateTime.now();
    switch (_advanced) {
      case AdvancedPeriod.monthNamed:
        if (_advMonth == null || _advYear == null) return null;
        final start = _startOfMonth(_advYear!, _advMonth!);
        final end = _endOfMonth(_advYear!, _advMonth!);
        return DateTimeRange(start: start, end: end);
      case AdvancedPeriod.bimestre:
        if (_advBimesterStart == null || _advYear == null) return null;
        final start = _startOfMonth(_advYear!, _advBimesterStart!);
        final endDate = _endOfMonth(_advYear!, _advBimesterStart!);
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

  // ---------- Filtragem e utilitários existentes ----------
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

  List<String> _availableCategories() {
    final Set<String> s = {};
    for (var raw in box.values) {
      try {
        final item = Map<String, dynamic>.from(raw as Map);
        if ((item['module'] ?? '') != 'Finanças') continue;
        s.add(_normalizeCategory(item['category']));
      } catch (_) {}
    }
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) s.add(t);
      }
    }
    // garante presença de '(Sem categoria)' e evita duplicatas
    s.add('(Sem categoria)');
    final list = s.toList()..sort();
    return ['(Todas)'] + list;
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
        if (_selectedCategory != null && _selectedCategory != '(Todas)' && category != _selectedCategory) continue;

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
    final Map<String, double> sums = { for (var m in paymentMethods) m: 0.0 };
    for (var item in items) {
      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(item['title'] as String? ?? '');
      final pm = (item['paymentMethod'] as String?) ?? 'Dinheiro/Pix';
      if (!sums.containsKey(pm)) sums[pm] = 0.0;
      sums[pm] = sums[pm]! + amt;
    }
    return sums;
  }

  String _generateCsv(List<Map<String, dynamic>> items) {
    final sb = StringBuffer();
    sb.writeln('timestamp,description,category,amount,payment_method,installment_number,installment_total,group_id');
    for (var it in items) {
      final ts = it['timestamp'] as String? ?? '';
      final title = (it['title'] as String?)?.replaceAll('"', '""') ?? '';
      final cat = _normalizeCategory(it['category']).replaceAll('"', '""');
      final amt = (it['amount'] is num) ? it['amount'].toString() : _extractAmount(title).toStringAsFixed(2);
      final pm = (it['paymentMethod'] as String?)?.replaceAll('"', '""') ?? '';
      final instNumber = (it['installmentNumber'] ?? '').toString();
      final instTotal = (it['installmentTotal'] ?? '').toString();
      final groupId = (it['installmentGroupId'] ?? '').toString();
      sb.writeln('"$ts","$title","$cat",$amt,"$pm",$instNumber,$instTotal,"$groupId"');
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
      // se cancelou, restaura label
      setState(() { _selectedPeriodOption = _labelForPeriod(); });
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

  // ---------- Funções de modal e seleção avançada ----------
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

    // atualiza label após ação
    setState(() {
      _selectedPeriodOption = _labelForPeriod();
    });
  }

  Future<void> _pickMonthNamed() async {
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    final res = await showDialog<Map<String,int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher mês e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
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
                Expanded(child: TextFormField(initialValue: year.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'), onChanged: (v) {
                  final y = int.tryParse(v);
                  if (y != null) setD(() => year = y);
                })),
              ]),
            ]);
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
    int start = 1; // 1,3,5,7,9,11
    final res = await showDialog<Map<String,int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher bimestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [1,3,5,7,9,11].map((m) => ChoiceChip(label: Text('${_monthName(m)}/${_monthName(_addMonthsClamped(DateTime(0,m,1),1).month)}'), selected: start==m, onSelected: (_) => setD(() => start = m))).toList()),
              const SizedBox(height: 12),
              TextFormField(initialValue: year.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'), onChanged: (v) {
                final y = int.tryParse(v);
                if (y != null) setD(() => year = y);
              }),
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
      setState(() { _advanced = AdvancedPeriod.none; _selectedPeriodOption = _labelForPeriod(); });
    }
  }

  Future<void> _pickQuarter() async {
    int year = DateTime.now().year;
    int quarter = 1;
    final res = await showDialog<Map<String,int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher trimestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [1,2,3,4].map((q) => ChoiceChip(label: Text('T$q'), selected: quarter==q, onSelected: (_) => setD(() => quarter = q))).toList()),
              const SizedBox(height: 12),
              TextFormField(initialValue: year.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'), onChanged: (v) {
                final y = int.tryParse(v);
                if (y != null) setD(() => year = y);
              }),
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
      setState(() { _advanced = AdvancedPeriod.none; _selectedPeriodOption = _labelForPeriod(); });
    }
  }

  Future<void> _pickSemester() async {
    int year = DateTime.now().year;
    int sem = 1;
    final res = await showDialog<Map<String,int>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher semestre e ano'),
          content: StatefulBuilder(builder: (ctx, setD) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [1,2].map((s) => ChoiceChip(label: Text('S$s'), selected: sem==s, onSelected: (_) => setD(() => sem = s))).toList()),
              const SizedBox(height: 12),
              TextFormField(initialValue: year.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'), onChanged: (v) {
                final y = int.tryParse(v);
                if (y != null) setD(() => year = y);
              }),
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
      setState(() { _advanced = AdvancedPeriod.none; _selectedPeriodOption = _labelForPeriod(); });
    }
  }

  Future<void> _pickYear() async {
    int year = DateTime.now().year;
    final res = await showDialog<int>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Escolher ano'),
          content: TextFormField(initialValue: year.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'), onChanged: (v) {
            final y = int.tryParse(v);
            if (y != null) year = y;
          }),
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
      setState(() { _advanced = AdvancedPeriod.none; _selectedPeriodOption = _labelForPeriod(); });
    }
  }

  // ---------- Funções de parcelamento/edição/serie ----------
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
      setState(() {});
    }
  }

  void _showParcelOptions(BuildContext context, dynamic key, Map<String, dynamic> existing) {
    final groupId = existing['installmentGroupId'] as String?;
    showModalBottomSheet(context: context, builder: (ctx) {
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
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      );
    });
  }

  String _baseTitleFromParcelTitle(String title) {
    return title.replaceAll(RegExp(r'\s*\(\d+/\d+\)\s*$'), '').trim();
  }

  // editar série inteira: abre modal com valores do grupo (base) e recria o grupo mantendo groupId
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

    final titleCtrl = TextEditingController(text: baseTitle);
    final amountCtrl = TextEditingController(text: currentTotal.toStringAsFixed(2));
    final installmentCtrl = TextEditingController(text: currentInstallments.toString());
    DateTime selectedDate = firstTs;
    String selectedCategory = currentCategory == '(Sem categoria)' ? '(Sem categoria)' : currentCategory;
    String selectedPaymentMethod = currentPaymentMethod;

    final LinkedHashSet<String> catSet = LinkedHashSet<String>();
    catSet.add('(Sem categoria)');
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) catSet.add(t);
      }
    }
    // agora mutável
    List<String> catOptions = catSet.toList();

    // se selectedCategory não estiver na lista, normaliza
    if (!catOptions.contains(selectedCategory)) {
      selectedCategory = '(Sem categoria)';
    }

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
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

                      // procura correspondência case-insensitive e mantém a capitalização original
                      String? storedMatch;
                      for (var val in categoriesBox.values) {
                        if (val is String && val.trim().toLowerCase() == newCatTrim.toLowerCase()) {
                          storedMatch = val.trim();
                          break;
                        }
                      }

                      // se não existe, adiciona
                      if (storedMatch == null) {
                        categoriesBox.add(newCatTrim);
                      }

                      final stored = storedMatch ?? newCatTrim;

                      // RECONSTRÓI a lista local de opções para que o Dropdown tenha o item
                      final LinkedHashSet<String> updatedSet = LinkedHashSet<String>();
                      updatedSet.add('(Sem categoria)');
                      for (var c in categoriesBox.values) {
                        if (c is String) {
                          final t = c.trim();
                          if (t.isNotEmpty) updatedSet.add(t);
                        }
                      }

                      // atualiza o estado do modal: nova lista e seleção
                      setModal(() {
                        catOptions = updatedSet.toList();
                        selectedCategory = stored;
                      });
                    }
                  } else {
                    setModal(() { selectedCategory = v; });
                  }
                },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedPaymentMethod,
                items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setModal(() => selectedPaymentMethod = v ?? paymentMethods.first),
                decoration: const InputDecoration(labelText: 'Método de pagamento'),
              ),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total')),
              const SizedBox(height: 8),
              TextField(controller: installmentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de parcelas')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) {
                    setModal(() {
                      selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute);
                    });
                  }
                }, icon: const Icon(Icons.calendar_month), label: Text(_formatDate(selectedDate)))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () {
                  final titleBase = titleCtrl.text.trim().isEmpty ? 'Despesa' : titleCtrl.text.trim();
                  final totalAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? _extractAmount(titleBase);
                  final installmentCount = int.tryParse(installmentCtrl.text.trim()) ?? 1;
                  final count = installmentCount < 1 ? 1 : installmentCount;
                  final categoryValue = selectedCategory == '(Sem categoria)' ? '' : selectedCategory;

                  // delete old group items
                  for (var it in groupItems) {
                    final k = it['_key'];
                    if (k != null) box.delete(k);
                  }

                  // recreate group with same groupId and selected payment method
                  for (int i = 0; i < count; i++) {
                    final dueDate = _addMonthsClamped(selectedDate, i);
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
                    };
                    final newKey = '$groupId-${i + 1}-${dueDate.year}${dueDate.month}${dueDate.day}';
                    box.put(newKey, item);
                  }

                  Navigator.pop(ctx);
                  setState(() {});
                }, child: const Text('Salvar série'))),
              ]),
              const SizedBox(height: 18),
            ]),
          ),
        );
      });
    });
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

  // Reutiliza o modal de criar/editar parcela única
  void _showAddOrEditExpense(BuildContext context, {dynamic key, Map<String, dynamic>? existing}) {
    final bool isEditing = key != null;

    final titleCtrl = TextEditingController(text: existing != null ? (existing['title'] as String? ?? '') : '');
    final amountCtrl = TextEditingController(text: existing != null ? ((existing['amount'] is num) ? existing['amount'].toString() : '') : '');
    final installmentCtrl = TextEditingController(text: existing != null && existing['installmentTotal'] != null ? existing['installmentTotal'].toString() : '1');
    DateTime selectedDate = existing != null ? (DateTime.tryParse(existing['timestamp'] as String? ?? '') ?? DateTime.now()) : DateTime.now();
    String selectedCategory = existing != null ? _normalizeCategory(existing['category']) : '(Sem categoria)';
    String selectedPaymentMethod = existing != null ? (existing['paymentMethod'] as String? ?? paymentMethods.first) : paymentMethods.first;

    // --- Modificado: usar LinkedHashSet para garantir unicidade ---
    final LinkedHashSet<String> catSet = LinkedHashSet<String>();
    catSet.add('(Sem categoria)');
    for (var c in categoriesBox.values) {
      if (c is String) {
        final t = c.trim();
        if (t.isNotEmpty) catSet.add(t);
      }
    }
    // agora mutável
    List<String> catOptions = catSet.toList();

    // se selectedCategory não estiver na lista, normaliza
    if (!catOptions.contains(selectedCategory)) {
      selectedCategory = '(Sem categoria)';
    }

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              Text(isEditing ? 'Editar despesa' : 'Adicionar despesa', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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

                      // procura correspondência case-insensitive e mantém a capitalização original
                      String? storedMatch;
                      for (var val in categoriesBox.values) {
                        if (val is String && val.trim().toLowerCase() == newCatTrim.toLowerCase()) {
                          storedMatch = val.trim();
                          break;
                        }
                      }

                      // se não existe, adiciona
                      if (storedMatch == null) {
                        categoriesBox.add(newCatTrim);
                      }

                      final stored = storedMatch ?? newCatTrim;

                      // RECONSTRÓI a lista local de opções para que o Dropdown tenha o item
                      final LinkedHashSet<String> updatedSet = LinkedHashSet<String>();
                      updatedSet.add('(Sem categoria)');
                      for (var c in categoriesBox.values) {
                        if (c is String) {
                          final t = c.trim();
                          if (t.isNotEmpty) updatedSet.add(t);
                        }
                      }

                      // atualiza o estado do modal: nova lista e seleção
                      setModal(() {
                        catOptions = updatedSet.toList();
                        selectedCategory = stored;
                      });
                    }
                  } else {
                    setModal(() { selectedCategory = v; });
                  }
                },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedPaymentMethod,
                items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setModal(() => selectedPaymentMethod = v ?? paymentMethods.first),
                decoration: const InputDecoration(labelText: 'Método de pagamento'),
              ),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total', hintText: 'Ex: 600.00')),
              const SizedBox(height: 10),
              TextField(controller: installmentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de parcelas', hintText: '1 = sem parcelamento')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) {
                    setModal(() {
                      selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute);
                    });
                  }
                }, icon: const Icon(Icons.calendar_month), label: Text(_formatDate(selectedDate)))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () {
                  final title = titleCtrl.text.trim().isEmpty ? 'Despesa' : titleCtrl.text.trim();
                  final totalAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? _extractAmount(title);
                  final installmentCount = int.tryParse(installmentCtrl.text.trim()) ?? 1;
                  final count = installmentCount < 1 ? 1 : installmentCount;
                  final categoryValue = selectedCategory == '(Sem categoria)' ? '' : selectedCategory;
                  final timestampBase = selectedDate;

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
                        };
                        box.add(item);
                      }
                    }
                  }

                  Navigator.pop(ctx);
                  setState(() {});
                }, child: Text(isEditing ? 'Salvar' : 'Criar'))),
              ]),
              const SizedBox(height: 18),
            ]),
          ),
        );
      });
    });
  }

  // ---------- Dedupe (limpeza) de categorias ----------
  // Remove entradas duplicadas (case-insensitive) do categoriesBox mantendo a primeira ocorrência.
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
        seen[norm] = val.trim(); // mantém capitalização da primeira ocorrência
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
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dedupe concluído — $removed duplicata(s) removida(s).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCats = _availableCategories();
    final items = _filteredFinanceItems();
    final total = _sumItems(items);
    final sumsByMethod = _sumByPaymentMethod(items);

    // lista de opções para o dropdown único
    final List<String> periodOptions = [
      'Hoje',
      'Semana',
      'Mês (escolher)', // abre modal
      'Trimestre',
      'Semestre',
      'Ano',
      'Personalizado',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
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
                    ElevatedButton(onPressed: () {
                      Clipboard.setData(ClipboardData(text: csv));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiado para a área de transferência')));
                    }, child: const Text('Copiar CSV')),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dedupe') _confirmAndDedupe();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'dedupe', child: Text('Limpar duplicatas de categorias')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddOrEditExpense(context), child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            // ---------- Dropdown usa _dropdownValue (valor fixo) ----------
            DropdownButton<String>(
              value: _dropdownValue,
              items: periodOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              onChanged: (v) async {
                if (v == null) return;
                // atualiza o valor do dropdown para um dos itens estáticos
                setState(() { _dropdownValue = v; });

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
                  // abre modal para escolher mês/ano — essa função já atualiza _selectedPeriodOption
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
                  // fallback: restaura label
                  setState(() { _selectedPeriodOption = _labelForPeriod(); });
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
            IconButton(tooltip: 'Limpar filtros', icon: const Icon(Icons.clear), onPressed: () {
              setState(() {
                _period = PeriodPreset.today;
                _customRange = null;
                _advanced = AdvancedPeriod.none;
                _selectedCategory = null;
                _search = '';
                _selectedPeriodOption = _labelForPeriod();
                _dropdownValue = 'Hoje';
              });
            }),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar descrição...'), onChanged: (v) => setState(() => _search = v))),
        SizedBox(height: 48, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), scrollDirection: Axis.horizontal, children: availableCats.map((c) {
          final isAll = c == '(Todas)';
          final selected = (_selectedCategory ?? '(Todas)') == c;
          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(c), selected: selected, onSelected: (_) { setState(() { _selectedCategory = isAll ? null : c; }); }));
        }).toList())),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Total no período'),
                  subtitle: Text(_labelForPeriod()),
                  trailing: Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                // Somas por método
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
        ),
        const SizedBox(height: 6),
        Expanded(child: ValueListenableBuilder(valueListenable: box.listenable(), builder: (context, Box b, _) {
          if (items.isEmpty) return const Center(child: Text('Nenhuma despesa neste período.'));
          return ListView.separated(padding: const EdgeInsets.all(12), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
            final item = items[i];
            final title = item['title'] as String? ?? '';
            final category = _normalizeCategory(item['category']);
            final ts = item['_ts'] as DateTime;
            final timeLabel = '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
            final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : _extractAmount(title);
            final key = item['_key'];
            final installmentInfo = item['installmentTotal'] != null ? 'Parcela ${item['installmentNumber']}/${item['installmentTotal']}' : '';
            final pm = (item['paymentMethod'] as String?) ?? '';

            return Dismissible(
              key: Key('$key-$i'),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent, child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (_) {
                if (key != null) b.delete(key);
                setState(() {});
              },
              child: ListTile(
                title: Text(title),
                // --- Modificado: mover método e horário para subtitle para evitar overflow no trailing ---
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
                        Flexible(
                          child: Text(pm, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 12),
                        Text(timeLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                trailing: Text('R\$ ${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  _showParcelOptions(context, key, item);
                },
              ),
            );
          });
        })),
      ]),
    );
  }

  Widget _paymentMethodIcon(String method) {
    switch (method) {
      case 'Dinheiro/Pix':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'Débito':
        return const Icon(Icons.credit_card, size: 16, color: Colors.blue);
      case 'Crédito':
        return const Icon(Icons.payment, size: 16, color: Colors.deepPurple);
      default:
        return const SizedBox(width: 16, height: 16);
    }
  }
}