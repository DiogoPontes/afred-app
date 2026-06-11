// lib/widgets/finance_charts.dart
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FinanceChartsModal extends StatefulWidget {
  final Box box; // caixa Hive onde estão os registros
  const FinanceChartsModal({Key? key, required this.box}) : super(key: key);

  @override
  State<FinanceChartsModal> createState() => _FinanceChartsModalState();
}

class _FinanceChartsModalState extends State<FinanceChartsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _monthRef = DateTime.now(); // mês selecionado para pizza
  int _daysWindow = 30;
  int _monthsWindow = 6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  List<Map<String, dynamic>> _financeItems() {
    final List<Map<String, dynamic>> out = [];
    for (var k in widget.box.keys) {
      final raw = widget.box.get(k);
      if (raw is Map) {
        final m = (raw['module'] as String?) ?? '';
        if (m.toLowerCase() == 'finanças') {
          final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
          dynamic t = item['timestamp'];
          DateTime? ts;
          if (t is String) ts = DateTime.tryParse(t);
          else if (t is int) ts = DateTime.fromMillisecondsSinceEpoch(t);
          else if (t is DateTime) ts = t;
          item['_ts'] = ts?.toLocal();
          out.add(item);
        }
      }
    }
    return out;
  }

  // Agrega por categoria para o mês referência (pizza)
  Map<String, double> _aggregateByCategoryForMonth(DateTime month) {
    final items = _financeItems();
    final Map<String, double> agg = {};
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));
    for (var it in items) {
      final ts = it['_ts'] as DateTime?;
      if (ts == null) continue;
      if (ts.isBefore(start) || ts.isAfter(end)) continue;
      final isIncome = it['isIncome'] as bool? ?? false;
      final amount = (it['amount'] as num?)?.toDouble() ?? 0.0;
      final category = ((it['category'] as String?)?.isNotEmpty ?? false) ? it['category'] as String : 'Sem categoria';
      if (isIncome) continue; // pulando receitas na pizza -> focando despesas
      agg[category] = (agg[category] ?? 0) + amount;
    }
    return agg;
  }

  // Agrega por dia para últimos N dias (linha)
  Map<DateTime, double> _aggregateDaily(int days) {
    final items = _financeItems();
    final Map<DateTime, double> agg = {};
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      agg[d] = 0.0;
    }
    for (var it in items) {
      final ts = it['_ts'] as DateTime?;
      if (ts == null) continue;
      final day = DateTime(ts.year, ts.month, ts.day);
      if (!agg.containsKey(day)) continue;
      final isIncome = it['isIncome'] as bool? ?? false;
      final amount = (it['amount'] as num?)?.toDouble() ?? 0.0;
      if (!isIncome) {
        agg[day] = (agg[day] ?? 0) + amount;
      }
    }
    return agg;
  }

  // Agrega por mês para últimos N meses (barra)
  Map<String, double> _aggregateMonthly(int months) {
    final items = _financeItems();
    final Map<String, double> agg = {};
    final now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      agg[key] = 0.0;
    }
    for (var it in items) {
      final ts = it['_ts'] as DateTime?;
      if (ts == null) continue;
      final key = '${ts.year}-${ts.month.toString().padLeft(2, '0')}';
      if (!agg.containsKey(key)) continue;
      final isIncome = it['isIncome'] as bool? ?? false;
      final amount = (it['amount'] as num?)?.toDouble() ?? 0.0;
      if (!isIncome) {
        agg[key] = (agg[key] ?? 0) + amount;
      }
    }
    return agg;
  }

  // ---------- Widgets dos charts ----------
  Widget _buildPieChart(Map<String, double> data) {
    if (data.isEmpty) {
      return const Center(child: Text('Sem despesas neste mês'));
    }
    final total = data.values.fold(0.0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];
    int i = 0;
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (var e in entries) {
      final value = e.value;
      final pct = total > 0 ? (value / total) * 100 : 0;
      final color = Colors.primaries[i % Colors.primaries.length].withOpacity(0.8);
      sections.add(PieChartSectionData(
        color: color,
        value: value,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    }

    return Column(
      children: [
        SizedBox(height: 220, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 36))),
        const SizedBox(height: 8),
        Text('Distribuição por categoria — total R\$ ${total.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: entries.map((e) {
            final idx = entries.indexOf(e);
            final color = Colors.primaries[idx % Colors.primaries.length].withOpacity(0.8);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 6),
                Text('${e.key} — R\$ ${e.value.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
              ],
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildLineChart(Map<DateTime, double> daily) {
    if (daily.isEmpty) return const Center(child: Text('Sem dados'));
    final entries = daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), (entries[i].value)));
    }
    final maxY = (entries.map((e) => e.value).fold(0.0, max) * 1.2).clamp(1.0, double.infinity);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: max(1.0, spots.length / 6),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt().clamp(0, entries.length - 1);
                      final dt = entries[idx].key;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text('${dt.day}/${dt.month}'),
                      );
                    },
                  ),
                ),
              ),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                  color: Colors.blueAccent,
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Últimos ${entries.length} dias — despesas por dia'),
      ],
    );
  }

  Widget _buildBarChart(Map<String, double> monthly) {
    if (monthly.isEmpty) return const Center(child: Text('Sem dados'));
    final entries = monthly.entries.toList();
    final maxY = (entries.map((e) => e.value).fold(0.0, max) * 1.2).clamp(1.0, double.infinity);
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(toY: entries[i].value, color: Colors.deepOrangeAccent, width: 16),
        ],
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: groups,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt().clamp(0, entries.length - 1);
                      final label = entries[idx].key.split('-');
                      final y = label[0];
                      final m = int.tryParse(label[1]) ?? 1;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '$m/$y',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Últimos ${entries.length} meses — despesas por mês'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final byCategory = _aggregateByCategoryForMonth(_monthRef);
    final daily = _aggregateDaily(_daysWindow);
    final monthly = _aggregateMonthly(_monthsWindow);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos Financeiros'),
        actions: [
          IconButton(
            tooltip: 'Escolher mês',
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _monthRef,
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                selectableDayPredicate: (d) => d.day == 1, // orientação apenas
              );
              if (picked != null) {
                setState(() {
                  _monthRef = DateTime(picked.year, picked.month, 1);
                });
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Categoria'),
            Tab(icon: Icon(Icons.show_chart), text: 'Últimos 30d'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Últimos meses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildPieChart(byCategory)),
          SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildLineChart(daily)),
          SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildBarChart(monthly)),
        ],
      ),
    );
  }
}