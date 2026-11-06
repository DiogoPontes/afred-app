// lib/widgets/finance_charts.dart

import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// Tela completa (full screen) que mostra gráficos/estatísticas financeiras.
/// Aceita opcionalmente uma lista de items filtrados e um total calculado.
class FinanceChartsScreen extends StatefulWidget {
  final Box box;
  final List<Map<String, dynamic>>? items;
  final double? total;

  const FinanceChartsScreen({Key? key, required this.box, this.items, this.total}) : super(key: key);

  @override
  State<FinanceChartsScreen> createState() => _FinanceChartsScreenState();
}

class _FinanceChartsScreenState extends State<FinanceChartsScreen> {
  late List<Map<String, dynamic>> _items;
  late double _total;

  LinkedHashMap<String, double> _byCategory = LinkedHashMap();

  // UI state
  int _touchedPieIndex = -1;

  // Active toggles
  final Map<String, bool> _activeCategory = {};

  final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');

  final List<Color> _palette = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.brown,
    Colors.cyan,
    Colors.indigo,
    Colors.lime,
    Colors.pink,
    Colors.amber,
    Colors.grey,
    Colors.deepPurple,
  ];

  // Max distinct slices before grouping into "Outros"
  final int _maxSlicesBeforeGrouping = 14;

  @override
  void initState() {
    super.initState();

    if (widget.items != null) {
      _items = widget.items!.map((e) => Map<String, dynamic>.from(e)).toList();
      _total = _calculateTotalFromItems(_items);
    } else {
      _loadFromBox();
    }

    _aggregateAll();
    _initActiveMaps();
  }

  // -----------------------
  // Parsing utilities
  // -----------------------
  dynamic _valueFromItem(Map<String, dynamic> it) {
    const candidates = [
      'amount',
      'value',
      'valor',
      'amount_value',
      'amountValue',
      'amt',
      'valor_num'
    ];
    for (final k in candidates) {
      if (it.containsKey(k) && it[k] != null) return it[k];
    }
    for (final entry in it.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('amount') || key.contains('val') || key.contains('quant')) {
        if (entry.value != null) return entry.value;
      }
    }
    return 0;
  }

  double _numFromDynamic(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    String s = v.toString().trim();
    if (s.isEmpty) return 0.0;
    s = s.replaceAll(RegExp(r'[^\d\-,.]'), '');
    if (s.contains('.') && s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '.');
    }
    if (s == '-' || s == '') return 0.0;
    return double.tryParse(s) ?? 0.0;
  }

  double _calculateTotalFromItems(List<Map<String, dynamic>> items) {
    double t = 0.0;
    for (final it in items) t += _numFromDynamic(_valueFromItem(it));
    return t;
  }

  // -----------------------
  // Load & aggregate
  // -----------------------
  void _loadFromBox() {
    _items = [];
    _total = 0.0;
    try {
      final raw = widget.box.values.toList();
      for (final r in raw) {
        if (r is Map) _items.add(Map<String, dynamic>.from(r as Map));
        else if (r is Map<String, dynamic>) _items.add(Map<String, dynamic>.from(r));
      }
      _total = _calculateTotalFromItems(_items);
    } catch (e) {
      _items = [];
      _total = 0.0;
    }
  }

  void _aggregateAll() {
    _byCategory = LinkedHashMap();

    for (final it in _items) {
      final cat = _stringFromField(it, ['category', 'categoria', 'cat']) ?? 'Sem categoria';
      final val = _numFromDynamic(_valueFromItem(it));
      _byCategory[cat] = (_byCategory[cat] ?? 0.0) + val;
    }
  }

  String? _stringFromField(Map<String, dynamic> it, List<String> candidates) {
    for (final k in candidates) {
      if (it.containsKey(k) && it[k] != null) return it[k].toString();
    }
    for (final entry in it.entries) {
      final key = entry.key.toLowerCase();
      if (candidates.any((c) => key.contains(c.toLowerCase()))) {
        if (entry.value != null) return entry.value.toString();
      }
    }
    return null;
  }

  void _initActiveMaps() {
    _activeCategory.clear();
    _byCategory.keys.forEach((k) => _activeCategory[k] = true);
  }

  // -----------------------
  // Helpers
  // -----------------------
  List<MapEntry<String, double>> _sortedEntries(LinkedHashMap<String, double> map) {
    final list = map.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<MapEntry<String, double>> _activeEntries(LinkedHashMap<String, double> map, Map<String, bool> activeMap) {
    final entries = _sortedEntries(map);
    return entries.where((e) => activeMap[e.key] ?? true).toList();
  }

  // -----------------------
  // Pie chart + legend (no duplicate legend)
  // -----------------------
  Widget _pieChartWithLegend({double height = 320}) {
    if (_byCategory.isEmpty) return const Center(child: Text('Sem dados de categoria'));

    final entriesAll = _sortedEntries(_byCategory);

    // Decide grouping: if few categories, show all; if many, group after limit.
    final shouldGroup = entriesAll.length > _maxSlicesBeforeGrouping;
    final display = <MapEntry<String, double>>[];
    if (!shouldGroup) {
      display.addAll(entriesAll);
    } else {
      display.addAll(entriesAll.sublist(0, _maxSlicesBeforeGrouping));
      final others = entriesAll.sublist(_maxSlicesBeforeGrouping).fold<double>(0.0, (p, e) => p + e.value);
      if (others > 0) display.add(MapEntry('Outros', others));
    }

    // Build sections only for active display entries
    final activeDisplay = display.where((e) => _activeCategory[e.key] ?? true).toList();
    final totalActive = activeDisplay.fold<double>(0.0, (p, e) => p + e.value);

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < display.length; i++) {
      final e = display[i];
      final active = _activeCategory[e.key] ?? true;
      if (!active) {
        sections.add(PieChartSectionData(value: 0.0001, color: _palette[i % _palette.length].withOpacity(0.08), title: '', radius: 0));
        continue;
      }
      final percent = totalActive > 0 ? e.value / totalActive : 0.0;
      final isTouched = i == _touchedPieIndex;
      sections.add(PieChartSectionData(
        color: _palette[i % _palette.length],
        value: e.value,
        title: '${(percent * 100).toStringAsFixed(0)}%',
        radius: isTouched ? 78 : 60,
        titleStyle: TextStyle(fontSize: isTouched ? 14 : 12, color: Colors.white, fontWeight: FontWeight.bold),
      ));
    }

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(display.length, (i) {
        final e = display[i];
        final active = _activeCategory[e.key] ?? true;
        return InkWell(
          onTap: () {
            setState(() {
              _activeCategory[e.key] = !active;
              _touchedPieIndex = -1;
            });
          },
          child: Opacity(
            opacity: active ? 1.0 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: _palette[i % _palette.length], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(currencyFormatter.format(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      }),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 620;
      return Card(
        elevation: 0,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: isWide
              ? Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: height,
                        child: PieChart(PieChartData(
                          sections: sections,
                          centerSpaceRadius: 48,
                          sectionsSpace: 2,
                          borderData: FlBorderData(show: false),
                          pieTouchData: PieTouchData(touchCallback: (event, resp) {
                            if (resp == null || resp.touchedSection == null) {
                              setState(() => _touchedPieIndex = -1);
                              return;
                            }
                            setState(() => _touchedPieIndex = resp.touchedSection!.touchedSectionIndex);
                          }),
                        )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: SingleChildScrollView(child: legend)),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: PieChart(PieChartData(
                        sections: sections,
                        centerSpaceRadius: 36,
                        sectionsSpace: 2,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData(touchCallback: (event, resp) {
                          if (resp == null || resp.touchedSection == null) {
                            setState(() => _touchedPieIndex = -1);
                            return;
                          }
                          setState(() => _touchedPieIndex = resp.touchedSection!.touchedSectionIndex);
                        }),
                      )),
                    ),
                    const SizedBox(height: 8),
                    legend,
                  ],
                ),
        ),
      );
    });
  }

  Widget _sectionTitle(String title) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)));
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    _aggregateAll(); // refresh
    // ensure active maps contain current keys (in case of data change)
    _byCategory.keys.forEach((k) {
      if (!_activeCategory.containsKey(k)) _activeCategory[k] = true;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos e estatísticas'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                currencyFormatter.format(_calculateTotalFromItems(_items)),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Por Categoria'),
              _pieChartWithLegend(height: 320),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}