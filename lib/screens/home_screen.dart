// lib/screens/home_screen.dart
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'focus_screen.dart';
import 'detect_rules_screen.dart';
import 'modules_screen.dart';
import 'module_records_screen.dart';
import '../widgets/alfred_fab.dart';
import '../services/backup_service.dart';
import '../services/day_records.dart';
import '../services/supabase_service.dart';
import 'finance_screen.dart';
import '../widgets/finance_record_form.dart';
import '../widgets/activity_record_form.dart';
import 'shopping_screen.dart';
import 'notes_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box box;
  DateTime _selectedDate = DateTime.now();

  Box? _shoppingProductsBox;
  Box? _shoppingListBox;
  Box? _shoppingSavedBox;
  Box? _notesBox;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  String _noteKeyForDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  

  Widget _notesSquare() {
    final notesBox =
        Hive.isBoxOpen('alfred_daily_notes')
            ? Hive.box('alfred_daily_notes')
            : null;
    final note = _notesBox?.get('anotacoes_gerais')?.toString();
    final color = Colors.blueGrey;

    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openNotes,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.blueGrey,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note == null || note.trim().isEmpty
                        ? 'Toque para escrever'
                        : note.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const Text(
                    'Anotações',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Este dia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
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

  String get _userEmail =>
      SupabaseService.client.auth.currentUser?.email ?? 'Sessão expirada';

  String get _userName {
    final meta = SupabaseService.client.auth.currentUser?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name'])?.toString();

    if (name != null && name.trim().isNotEmpty) return name;

    return _userEmail;
  }

  String? get _userAvatarUrl =>
      SupabaseService.client.auth.currentUser?.userMetadata?['avatar_url']
          ?.toString();

  Widget _userAvatar() {
    final url = _userAvatarUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url), radius: 14);
    }

    return const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16));
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja sair da sua conta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SupabaseService.signOut();
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    box = Hive.box('alfred_box');
    _openShoppingBoxes();
    _openNotesBox();
  }

  Future<void> _openNotesBox() async {
    try {
      if (!Hive.isBoxOpen('alfred_daily_notes')) {
        await Hive.openBox('alfred_daily_notes');
      }

      if (!mounted) return;

      setState(() {
        _notesBox = Hive.box('alfred_daily_notes');
      });
    } catch (e) {
      debugPrint('Erro ao abrir box de anotações: $e');
    }
  }

  Future<void> _openNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotesScreen(),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openShoppingBoxes() async {
    try {
      if (!Hive.isBoxOpen('alfred_shopping_products')) {
        await Hive.openBox('alfred_shopping_products');
      }

      if (!Hive.isBoxOpen('alfred_shopping_list')) {
        await Hive.openBox('alfred_shopping_list');
      }

      if (!Hive.isBoxOpen('alfred_shopping_saved')) {
        await Hive.openBox('alfred_shopping_saved');
      }

      if (!mounted) return;

      setState(() {
        _shoppingProductsBox = Hive.box('alfred_shopping_products');
        _shoppingListBox = Hive.box('alfred_shopping_list');
        _shoppingSavedBox = Hive.box('alfred_shopping_saved');
      });
    } catch (e) {
      debugPrint('Erro ao abrir boxes de compras: $e');
    }
}

  String get _dateLabel => dayLabelOf(_selectedDate, showToday: _isToday);

  Future<void> _openModule(String module) async {
    if (module == 'Compras') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ShoppingScreen(),
        ),
      );

      if (mounted) {
        setState(() {});
      }

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleRecordsScreen(
          module: module,
          date: _selectedDate,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openFocusMode() async {
    final items = itemsForDay(DateTime.now());
    final pending = items
        .where((it) => (it['module'] as String? ?? '') == 'Tarefas' &&
            it['isDone'] != true)
        .map((it) => it['title']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    if (!mounted) return;

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhuma tarefa pendente para o modo foco.')));
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Focar em qual tarefa?'),
        children: [
          for (final t in pending)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(t),
              child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FocusScreen(taskTitle: chosen)),
    );
  }

  // ---- Detecção de módulo (Quick Add) ----

  /// Sinais fortes de contexto financeiro. Se algum aparecer,
  /// o módulo Finanças vence, mesmo que o texto cite coisas de
  /// outros módulos (ex: "gastei 50 na pizzaria no credito").
  static const List<String> _financeSignals = [
    'gastei', 'gasto', 'paguei', 'pagar', 'comprei', 'custou',
    'custa', 'recebi', 'ganhei', 'reais', 'r\$',
    'credito', 'crédito', 'debito', 'débito',
    'pix', 'dinheiro', 'cartao', 'cartão', 'fatura',
  ];

  // Sinais de atividade física. Têm prioridade sobre as regras
  // configuradas, mas perdem para sinais financeiros.
  static const List<String> _activitySignals = [
    'corri', 'corrida', 'correr', 'correndo', 'correu',
    'musculacao', 'musculação', 'treinei', 'treino', 'academia',
    'yoga', 'natacao', 'natação', 'ciclismo', 'pedalei',
    'exercicio', 'exercício',
  ];

  String detectModule(String text) {
    final lower = text.toLowerCase();

    // 1. Sinais financeiros têm prioridade máxima
    for (final signal in _financeSignals) {
      if (lower.contains(signal)) return 'Finanças';
    }

    // 2. Sinais de atividade física
    for (final signal in _activitySignals) {
      if (lower.contains(signal)) return 'Atividade Física';
    }

    // 3. Sem sinal financeiro, aplica as regras configuradas
    final rulesBox = Hive.box('alfred_detect_rules');
    for (var module in rulesBox.keys) {
      final raw = rulesBox.get(module);
      if (raw == null) continue;
      final words = List<String>.from(raw as List);
      for (var word in words) {
        if (lower.contains(word.toLowerCase())) return module as String;
      }
    }

    return 'Tarefas';
  }

  String? _extractDescriptionFromText(String text) {
    String cleaned = text.toLowerCase();

    cleaned = cleaned.replaceAll(
      RegExp(r'(?:(?:r\$)\s*)?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?'),
      ' ',
    );

    final wordsToRemove = [
      'gastei', 'paguei', 'pagar', 'comprei', 'gasto', 'gastar', 'gastos',
      'recebi', 'ganhei', 'salário', 'salario', 'receita', 'deposito', 'depósito',
      'crédito', 'credito', 'débito', 'debito', 'pix', 'transferencia',
      'transferência', 'cartao', 'cartão', 'dinheiro', 'fatura',
      'no', 'na', 'do', 'da', 'em', 'com', 'de', 'para', 'um', 'uma', 'reais',
    ];

    for (final w in wordsToRemove) {
      cleaned = cleaned.replaceAll(RegExp('\\b$w\\b'), ' ');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  // ---- Quick Add ----

  Future<void> _showQuickAdd() async {
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickAddSheet(
        detectModule: detectModule,
        extractDescription: _extractDescriptionFromText,
        colorForModule: moduleColorOf,
        iconForModule: moduleIconOf,
        onSaved: () => setState(() {}),
      ),
    );
  }

  List<Map<String, dynamic>> _shoppingDashboardItems() {
    final savedBox = _shoppingSavedBox;
    if (savedBox == null) return [];

    final d = _selectedDate;
    final dayKey =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final raw = savedBox.get(dayKey);
    if (raw is! Map) return [];

    final snapshot = Map<String, dynamic>.from(raw);
    final itemsRaw = snapshot['items'];
    if (itemsRaw is! List) return [];

    final result = <Map<String, dynamic>>[];

    for (final entry in itemsRaw) {
      if (entry is! Map) continue;

      final item = Map<String, dynamic>.from(entry);

      final qty = item['quantity'] is num
          ? (item['quantity'] as num).toDouble()
          : double.tryParse(
                item['quantity']?.toString().replaceAll(',', '.') ?? '',
              ) ??
              0;

      final lineTotal = item['lineTotal'] is num
          ? (item['lineTotal'] as num).toDouble()
          : double.tryParse(
                item['lineTotal']?.toString().replaceAll(',', '.') ?? '',
              ) ??
              (item['price'] is num
                  ? (item['price'] as num).toDouble()
                  : double.tryParse(
                        item['price']?.toString().replaceAll(',', '.') ?? '',
                      ) ??
                      0);

      result.add({
        'title': item['name']?.toString() ?? 'Produto',
        'module': 'Compras',
        '_shoppingUnits': qty.round(),
        '_shoppingLineTotal': lineTotal,
        'isBought': item['isBought'] == true,
      });
    }

    return result;
  }

  // ---- Dashboard ----

  Widget _moduleSquare(String module, List<Map<String, dynamic>> items) {
    final color = moduleColorOf(module);
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openModule(module),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Center(
                        child: Icon(moduleIconOf(module),
                            color: Colors.white, size: 18)),
                  ),
                  Icon(Icons.chevron_right, color: color, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module == 'Compras'
                        ? '${items.length} ${items.length == 1 ? 'produto' : 'produtos'}'
                        : '${items.length} ${items.length == 1 ? 'registro' : 'registros'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    module,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    moduleSummary(module, items),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ALFRED',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_dateLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDay(-1)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeDay(1)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              switch (val) {
                case 'modules':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ModulesScreen()),
                  );
                  break;
                case 'detect_rules':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DetectRulesScreen()),
                  );
                  break;
                case 'focus':
                  await _openFocusMode();
                  break;
                case 'backup_copy':
                  final json = await BackupService.exportBackupJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Backup copiado para a área de transferência')));
                  break;
                case 'backup_restore':
                  await BackupService.restoreFromAsset(
                      'assets/backups/dev_backup.json');
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Backup restaurado com sucesso')));
                  break;
                case 'sign_out':
                  _confirmSignOut();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Row(
                  children: [
                    _userAvatar(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(_userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'modules',
                  child: ListTile(
                      leading: Icon(Icons.view_list), title: Text('Módulos'))),
              const PopupMenuItem(
                  value: 'detect_rules',
                  child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Regras de Detecção'))),
              const PopupMenuItem(
                  value: 'focus',
                  child: ListTile(
                      leading: Icon(Icons.center_focus_strong),
                      title: Text('Modo Foco'))),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'backup_copy',
                  child: ListTile(
                      leading: Icon(Icons.copy_all),
                      title: Text('Copiar Backup'))),
              const PopupMenuItem(
                  value: 'backup_restore',
                  child: ListTile(
                      leading: Icon(Icons.restore),
                      title: Text('Restaurar Backup'))),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'sign_out',
                  child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Sair',
                          style: TextStyle(color: Colors.red)))),
            ],
          ),
        ],
      ),
      floatingActionButton: AlfredFab(onTap: _showQuickAdd),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: recordsListenable(),
          builder: (context, _) {
            final items = itemsForDay(_selectedDate);

            // Agrupa os registros diários por módulo.
            final byModule =
                SplayTreeMap<String, List<Map<String, dynamic>>>();

            for (final it in items) {
              final m = it['module'] as String? ?? 'Tarefas';
              byModule.putIfAbsent(m, () => []).add(it);
            }

            // Compras é uma lista persistente, não um registro diário.
            // Ela aparece no dashboard somente quando há itens na lista atual.
            final shoppingItems = _shoppingDashboardItems();

            if (shoppingItems.isNotEmpty) {
              byModule['Compras'] = shoppingItems;
            }
            final modules = byModule.keys.toList();

            

           return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'registro' : 'registros'} neste dia',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: 130,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: modules.length + 1 + (modules.isEmpty ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index == 0) return _notesSquare();

                          if (modules.isEmpty) {
                            return Center(
                              child: Text(
                                'Nenhum registro neste dia.\nToque em + para adicionar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            );
                          }

                          final moduleIndex = index - 1;
                          return _moduleSquare(
                            modules[moduleIndex],
                            byModule[modules[moduleIndex]]!,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Folha do "Adicionar rapidamente".
/// Os controllers vivem aqui, então o próprio framework chama o dispose()
/// no momento certo (após a animação de fechamento), evitando o erro
/// "A TextEditingController was used after being disposed".
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({
    required this.detectModule,
    required this.extractDescription,
    required this.colorForModule,
    required this.iconForModule,
    required this.onSaved,
  });

  final String Function(String) detectModule;
  final String? Function(String) extractDescription;
  final Color Function(String) colorForModule;
  final IconData Function(String) iconForModule;
  final VoidCallback onSaved;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final TextEditingController textCtrl = TextEditingController();

  String _detectedModule = 'Tarefas';

  bool get _isFinance => _detectedModule.toLowerCase() == 'finanças';

  bool get _isActivity =>
      _detectedModule.toLowerCase() == 'atividade física';

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final module = widget.detectModule(value);

    setState(() {
      _detectedModule = module;
    });
  }

  bool _saveBasicRecord() {
    final text = textCtrl.text.trim();
    if (text.isEmpty) return false;

    Hive.box('alfred_box').add({
      'title': text,
      'module': _detectedModule,
      'timestamp': DateTime.now().toIso8601String(),
      'isDone': false,
      if (_detectedModule == 'Tarefas') 'priority': 'Média',
    });

    widget.onSaved();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final moduleColor = widget.colorForModule(_detectedModule);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Center(
              child: Text(
                'Adicionar rapidamente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Texto',
                hintText: 'Ex: Paguei 50 reais no almoço',
                border: OutlineInputBorder(),
              ),
              onChanged: _onTextChanged,
              onSubmitted: _onTextChanged,
            ),
            const SizedBox(height: 16),

            // Módulo detectado em tempo real
            Row(
              children: [
                const Text(
                  'Módulo detectado:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: moduleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.iconForModule(_detectedModule),
                          size: 14, color: moduleColor),
                      const SizedBox(width: 6),
                      Text(
                        _detectedModule,
                        style: TextStyle(
                          fontSize: 12,
                          color: moduleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isFinance) ...[
              const SizedBox(height: 16),

              FinanceRecordForm(
                key: const ValueKey('quick_add_finance_form'),
                embedded: true,
                initialDescription: widget.extractDescription(textCtrl.text),
                initialRawText: textCtrl.text,
                onSaved: () {
                  widget.onSaved();
                  Navigator.of(context).pop();
                },
                availableCards: availableFinanceCards,
                showCardForm: (hiveKey) {
                  return showFinanceCardForm(context, hiveKey);
                },
              ),
            ] else if (_isActivity) ...[
              const SizedBox(height: 16),

              ActivityRecordForm(
                key: const ValueKey('quick_add_activity_form'),
                embedded: true,
                initialRawText: textCtrl.text,
                onSaved: () {
                  widget.onSaved();
                  Navigator.of(context).pop();
                },
              ),
            ] else ...[
              Text(
                'O texto será salvo como registro em "$_detectedModule".',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final ok = _saveBasicRecord();
                    if (ok) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: Text('Salvar em $_detectedModule'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}