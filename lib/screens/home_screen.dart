// lib/screens/home_screen.dart
import 'dart:collection';
import 'focus_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/alfred_fab.dart';
import 'modules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box box;

  // mapa de cores sutis por módulo
  final Map<String, Color> _moduleColors = {
    'Tarefas': Colors.blueGrey,
    'Finanças': Colors.deepOrange,
    'Exercício': Colors.green,
    'Alimentação': Colors.pink,
    'Estudos': Colors.indigo,
    'Compromissos': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box');
  }

  String detectModule(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'gastei|r\$|reais|paguei|pagar|comprei').hasMatch(lower)) {
      return 'Finanças';
    } else if (RegExp(r'corri|treino|academia|km|corrida|malhei|muscula').hasMatch(lower)) {
      return 'Exercício';
    } else if (RegExp(r'comi|almoç|jantar|lanche|pizza|refei').hasMatch(lower)) {
      return 'Alimentação';
    } else if (RegExp(r'estud|prova|revisar|aula|curso').hasMatch(lower)) {
      return 'Estudos';
    } else if (RegExp(r'reuni|médic|dentista|encontro|agenda').hasMatch(lower)) {
      return 'Compromissos';
    }
    return 'Tarefas';
  }

  Color _colorForModule(String module) {
    if (_moduleColors.containsKey(module)) {
      return _moduleColors[module]!;
    }
    final palette = [Colors.cyan, Colors.deepPurple, Colors.amber, Colors.lime, Colors.brown];
    final idx = module.hashCode.abs() % palette.length;
    return palette[idx];
  }

  // ---------- Parser de texto livre para finanças ----------
  // Extrai valor, método de pagamento e indicação de receita/despesa a partir do texto livre
  Map<String, dynamic> _parseFinanceFromText(String text) {
    final lower = text.toLowerCase();

    // Captura primeiro número com decimais opcionais (suporta formatos como 1.234,56 / 1234.56 / 50)
    final numMatch = RegExp(r'(?:(?:r\$)\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)').firstMatch(lower);
    double? amount;
    if (numMatch != null) {
      var raw = numMatch.group(1)!;
      // remove separador de milhares e normaliza vírgula -> ponto
      raw = raw.replaceAll('.', '');
      raw = raw.replaceAll(',', '.');
      amount = double.tryParse(raw);
    }

    // Detecta método de pagamento por palavras-chave
    String? method;
    if (RegExp(r'\b(cr[eé]dito|credito)\b').hasMatch(lower)) method = 'Crédito';
    else if (RegExp(r'\b(d[eé]bito|debito)\b').hasMatch(lower)) method = 'Débito';
    else if (RegExp(r'\bpix\b').hasMatch(lower)) method = 'Dinheiro/Pix';
    else if (RegExp(r'\btransfer[eê]ncia\b|\btransferencia\b|\btransferir\b').hasMatch(lower)) method = 'Transferência';
    else if (RegExp(r'\bdinheiro\b|\bcash\b').hasMatch(lower)) method = 'Dinheiro/Pix';

    // Detecta se o texto indica receita (true) ou despesa (false) quando possível
    bool? isIncome;
    if (RegExp(r'\b(recebi|ganhei|sal[aá]rio|salario|receita|deposito|dep[oó]sito)\b').hasMatch(lower)) isIncome = true;
    if (RegExp(r'\b(gastei|paguei|pagar|comprei|gasto|gastar)\b').hasMatch(lower)) isIncome = false;

    return {
      'amount': amount, // double? (ex: 50.0)
      'paymentMethod': method, // String? (ex: 'Crédito')
      'isIncome': isIncome, // bool? (true=receita, false=despesa, null=indefinido)
    };
  }

  List<String> _availableModules() {
    final defaults = ['Tarefas', 'Finanças', 'Exercício', 'Alimentação', 'Estudos', 'Compromissos'];
    final LinkedHashSet<String> set = LinkedHashSet<String>.from(defaults);

    for (var key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;
        final item = Map<String, dynamic>.from(raw as Map);
        final m = (item['module'] as String?)?.trim();
        if (m != null && m.isNotEmpty) set.add(m);
      } catch (_) {}
    }
    return set.toList();
  }

  void _showQuickAdd() {
    // Quick Add com opção de formulário financeiro quando módulo = "Finanças"
    final categoriesBox = Hive.box('alfred_finance_categories');

    String detectedModule = 'Tarefas';
    String selectedModule = detectedModule;
    bool manuallySelected = false;
    bool useSuggestion = false;

    final TextEditingController textCtrl = TextEditingController();

    // campos financeiros locais
    bool financeIsIncome = false;
    final TextEditingController financeAmountCtrl = TextEditingController();
    String financeCategory = '(Sem categoria)';
    String financePaymentMethod = 'Dinheiro/Pix';
    final TextEditingController financeInstallmentsCtrl = TextEditingController(text: '1');
    DateTime financeDate = DateTime.now();

    // flags para evitar sobrescrever edição manual
    bool financeAmountAutoFilled = false;
    bool financeMethodManuallyEdited = false;

    List<String> paymentMethods = ['Dinheiro/Pix', 'Débito', 'Crédito'];
    List<String> incomeMethods = ['Transferência', 'PIX', 'Dinheiro'];

    List<String> _financeCategories() {
      final set = <String>{'(Sem categoria)'};
      for (var v in categoriesBox.values) {
        if (v is String && v.trim().isNotEmpty) set.add(v.trim());
      }
      return set.toList()..sort();
    }

    List<String> modules() {
      final m = _availableModules();
      if (!m.contains(selectedModule)) {
        m.insert(0, selectedModule);
      }
      return m;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          // recalcula sugestão sempre que o texto muda
          final currentDetected = detectModule(textCtrl.text);
          if (!manuallySelected) {
            detectedModule = currentDetected;
            selectedModule = detectedModule;
          }
          final isFinance = selectedModule.toLowerCase() == 'finanças' || (useSuggestion && detectedModule.toLowerCase() == 'finanças');

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text('Adicionar rapidamente', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Ex: Gastei 50 no almoço'),
                  onChanged: (val) {
                    setModalState(() {
                      // atualiza sugestão de módulo
                      final newDetected = detectModule(val);
                      detectedModule = newDetected;
                      if (!manuallySelected) {
                        selectedModule = newDetected;
                      }

                      // parse financeiro
                      final parsed = _parseFinanceFromText(val);
                      final double? amt = parsed['amount'] as double?;
                      final String? pm = parsed['paymentMethod'] as String?;
                      final bool? inc = parsed['isIncome'] as bool?;

                      // Valor: atualiza normalmente enquanto o usuário não mexer manualmente no campo
                      if (amt != null && (financeAmountCtrl.text.isEmpty || financeAmountAutoFilled)) {
                        financeAmountCtrl.text = amt.toStringAsFixed(2);
                        financeAmountAutoFilled = true;
                      }

                      // Método de pagamento: atualiza dinamicamente se o usuário NÃO editou manualmente
                      if (pm != null && !financeMethodManuallyEdited) {
                        if (inc == true) {
                          financePaymentMethod = incomeMethods.contains(pm) ? pm : incomeMethods.first;
                        } else {
                          financePaymentMethod = paymentMethods.contains(pm) ? pm : paymentMethods.first;
                        }
                      }

                      // tipo receita/despesa
                      if (inc != null) {
                        financeIsIncome = inc;
                        if (financeIsIncome) {
                          if (!incomeMethods.contains(financePaymentMethod)) financePaymentMethod = incomeMethods.first;
                        } else {
                          if (!paymentMethods.contains(financePaymentMethod)) financePaymentMethod = paymentMethods.first;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Módulo atual com ponto colorido
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade600),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _colorForModule(selectedModule).withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(selectedModule, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          useSuggestion = true;
                          manuallySelected = false;
                          selectedModule = detectedModule;
                          // permitir que a sugestão re-aplique método se encontrado
                          financeMethodManuallyEdited = false;
                        });
                      },
                      child: const Text('Usar sugestão'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedModule,
                        items: modules().map((m) => DropdownMenuItem(
                          value: m,
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: _colorForModule(m).withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(m),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() {
                            selectedModule = v;
                            manuallySelected = true;
                            useSuggestion = false;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Trocar módulo',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        textCtrl.text.isEmpty ? 'Nenhuma descrição' : textCtrl.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                // Se for finanças, mostra o formulário financeiro inline
                if (isFinance) ...[
                  DropdownButtonFormField<String>(
                    value: financeIsIncome ? 'Receita' : 'Despesa',
                    items: const [
                      DropdownMenuItem(value: 'Despesa', child: Text('Despesa')),
                      DropdownMenuItem(value: 'Receita', child: Text('Receita')),
                    ],
                    onChanged: (v) => setModalState(() {
                      financeIsIncome = (v == 'Receita');
                      if (financeIsIncome) {
                        financePaymentMethod = incomeMethods.first;
                        financeInstallmentsCtrl.text = '1';
                        // permitir que o parser altere método se o texto indicar outro
                        financeMethodManuallyEdited = false;
                      } else {
                        if (financePaymentMethod == incomeMethods.first) financePaymentMethod = paymentMethods.first;
                        financeMethodManuallyEdited = false;
                      }
                    }),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 8),

                  // Descrição (reutiliza textCtrl para evitar criar controllers dinâmicos)
                  TextField(
                    controller: textCtrl,
                    onChanged: (v) {
                      // já está sincronizado por shared controller
                    },
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 8),

                  // Valor
                  TextField(
                    controller: financeAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor (Ex: 45.00)'),
                    onChanged: (_) {
                      // usuário mexeu manualmente -> não sobrescrever mais
                      financeAmountAutoFilled = false;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Categoria (somente para despesas)
                  if (!financeIsIncome) ...[
                    DropdownButtonFormField<String>(
                      value: financeCategory,
                      items: _financeCategories().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setModalState(() => financeCategory = v ?? '(Sem categoria)'),
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Método de pagamento
                  DropdownButtonFormField<String>(
                    value: financePaymentMethod,
                    items: (financeIsIncome ? incomeMethods : paymentMethods).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModalState(() {
                      financePaymentMethod = v ?? financePaymentMethod;
                      // marca que o usuário editou manualmente, assim o parser não sobrescreverá
                      financeMethodManuallyEdited = true;
                      if (!financeIsIncome && financePaymentMethod != 'Crédito') financeInstallmentsCtrl.text = '1';
                    }),
                    decoration: const InputDecoration(labelText: 'Método de pagamento'),
                  ),
                  const SizedBox(height: 8),

                  // Parcelas apenas para despesas com Crédito
                  if (!financeIsIncome && financePaymentMethod == 'Crédito') ...[
                    TextField(
                      controller: financeInstallmentsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Número de parcelas'),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Data
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: financeDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setModalState(() => financeDate = DateTime(picked.year, picked.month, picked.day, financeDate.hour, financeDate.minute));
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Data: ${financeDate.day}/${financeDate.month}/${financeDate.year}'),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Pequena opção de data para outros módulos (não obrigatória)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) {
                        // opcional: não armazenamos aqui, apenas permite ao usuário escolher se quiser
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Escolher data (opcional)'),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final text = textCtrl.text.trim();
                          if (isFinance) {
                            final amount = double.tryParse(financeAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                            final installments = int.tryParse(financeInstallmentsCtrl.text.trim()) ?? 1;
                            final count = installments < 1 ? 1 : installments;
                            final categoryValue = financeIsIncome ? 'Receita' : (financeCategory == '(Sem categoria)' ? '' : financeCategory);

                            if (count <= 1) {
                              final item = {
                                'title': text.isEmpty ? (financeIsIncome ? 'Receita' : 'Despesa') : text,
                                'module': 'Finanças',
                                'timestamp': financeDate.toIso8601String(),
                                'isDone': false,
                                'amount': amount,
                                'category': categoryValue,
                                'paymentMethod': financePaymentMethod,
                                'isIncome': financeIsIncome,
                              };
                              box.add(item);
                            } else {
                              final groupId = DateTime.now().millisecondsSinceEpoch.toString();
                              final totalAmount = amount;
                              for (int i = 0; i < count; i++) {
                                final due = DateTime(financeDate.year, financeDate.month + i, financeDate.day, financeDate.hour, financeDate.minute);
                                final installmentAmount = _installmentAmount(totalAmount, count, i);
                                final item = {
                                  'title': '${text.isEmpty ? (financeIsIncome ? 'Receita' : 'Despesa') : text} (${i + 1}/$count)',
                                  'module': 'Finanças',
                                  'timestamp': due.toIso8601String(),
                                  'isDone': false,
                                  'amount': installmentAmount,
                                  'category': categoryValue,
                                  'installmentTotal': count,
                                  'installmentNumber': i + 1,
                                  'installmentGroupId': groupId,
                                  'originalAmount': totalAmount,
                                  'paymentMethod': financePaymentMethod,
                                  'isIncome': financeIsIncome,
                                };
                                box.add(item);
                              }
                            }
                          } else {
                            if (text.isEmpty) return;
                            final item = {
                              'title': text,
                              'module': selectedModule.isEmpty ? '(Sem módulo)' : selectedModule,
                              'timestamp': DateTime.now().toIso8601String(),
                              'isDone': false,
                            };
                            box.put(DateTime.now().millisecondsSinceEpoch.toString(), item);
                          }

                          Navigator.of(context).pop();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          );
        });
      },
    );
  }

  void _toggleDone(dynamic key) {
    final raw = box.get(key);
    if (raw == null) return;
    final Map item = Map<String, dynamic>.from(raw as Map);
    item['isDone'] = !(item['isDone'] as bool);
    box.put(key, item);
  }

  void _deleteItem(dynamic key) {
    box.delete(key);
  }

  void _confirmDelete(dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Excluir registro'),
          content: const Text('Deseja excluir este registro permanentemente?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                _deleteItem(key);
                Navigator.of(ctx).pop();
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _itemsForToday(Box b) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final List<Map<String, dynamic>> items = [];

    for (var key in b.keys) {
      try {
        final raw = b.get(key);
        if (raw == null) continue;
        final item = Map<String, dynamic>.from(raw as Map);
        DateTime? ts;
        final t = item['timestamp'];
        if (t == null) continue;
        if (t is int) ts = DateTime.fromMillisecondsSinceEpoch(t);
        else if (t is String) ts = DateTime.tryParse(t);
        else if (t is DateTime) ts = t;

        if (ts == null) continue;
        ts = ts.toLocal();
        if (ts.isBefore(start) || ts.isAfter(end)) continue;

        final copy = Map<String, dynamic>.from(item);
        copy['_key'] = key;
        copy['_ts'] = ts;
        items.add(copy);
      } catch (_) {
        continue;
      }
    }
    items.sort((a, b) => (b['_ts'] as DateTime).compareTo(a['_ts'] as DateTime));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM', 'pt_BR').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
          Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          IconButton(
            tooltip: 'Módulos', icon: const Icon(Icons.view_list),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModulesScreen())),
          ),
          IconButton(tooltip: 'Relatório', icon: const Icon(Icons.bar_chart_outlined), onPressed: () {}),
          IconButton(
            tooltip: 'Foco',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FocusScreen(
                    taskTitle: 'Estudar Álgebra — Capítulo 3',
                    demoMode: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: AlfredFab(onTap: _showQuickAdd),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box b, _) {
            final items = _itemsForToday(b);
            if (items.isEmpty) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Nenhum registro para hoje. Toque em + para adicionar.',
                          style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center)));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                final key = item['_key'];
                final title = item['title'] as String? ?? '';
                final module = item['module'] as String? ?? '';
                final isDone = item['isDone'] as bool? ?? false;
                final ts = item['_ts'] as DateTime;
                final timeLabel = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

                return Dismissible(
                  key: Key(key.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteItem(key),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: GestureDetector(
                        onTap: () => _toggleDone(key),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDone ? Colors.green : Colors.transparent,
                            border: Border.all(color: isDone ? Colors.green : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isDone ? const Icon(Icons.check, color: Colors.white, size: 20) : const Icon(Icons.circle_outlined, size: 20),
                        ),
                      ),
                      title: Text(title,
                          style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                              color: isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge!.color,
                              fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _colorForModule(module), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(module),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(key)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // helper para calcular valor por parcela
  double _installmentAmount(double total, int count, int index) {
    if (count <= 1) return total;
    final base = double.parse((total / count).toStringAsFixed(2));
    if (index < count - 1) return base;
    final previous = base * (count - 1);
    return double.parse((total - previous).toStringAsFixed(2));
  }
}