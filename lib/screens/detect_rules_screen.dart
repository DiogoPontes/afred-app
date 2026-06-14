// lib/screens/detect_rules_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DetectRulesScreen extends StatefulWidget {
  const DetectRulesScreen({Key? key}) : super(key: key);

  @override
  State<DetectRulesScreen> createState() => _DetectRulesScreenState();
}

class _DetectRulesScreenState extends State<DetectRulesScreen> {
  late Box rulesBox;
  late Box modulesBox;

  // regras padrão por módulo
  static const Map<String, List<String>> _defaults = {
    'Finanças':        ['gastei', 'r\$', 'reais', 'paguei', 'pagar', 'comprei'],
    'Atividade Física':['corri', 'treino', 'academia', 'km', 'corrida', 'malhei', 'muscula', 'natação', 'ciclismo', 'yoga'],
    'Alimentação':     ['comi', 'almoç', 'jantar', 'lanche', 'pizza', 'refei'],
    'Estudos':         ['estud', 'prova', 'revisar', 'aula', 'curso'],
    'Compromissos':    ['reuni', 'médic', 'dentista', 'encontro', 'agenda'],
  };

  String? _selectedModule;
  List<String> _modules = [];

  @override
  void initState() {
    super.initState();
    rulesBox   = Hive.box('alfred_detect_rules');
    modulesBox = Hive.box('alfred_modules');

    // seed defaults se vazio
    if (rulesBox.isEmpty) {
      _defaults.forEach((mod, words) {
        rulesBox.put(mod, words);
      });
    }

    _loadModules();
  }

  void _loadModules() {
    final fromHive = modulesBox.values.cast<String>().toList();
    final defaults = ['Tarefas', 'Finanças', 'Atividade Física', 'Alimentação', 'Estudos', 'Compromissos'];
    final set = <String>{...defaults, ...fromHive};
    setState(() {
      _modules = set.toList()..sort();
      _selectedModule ??= _modules.first;
    });
  }

  List<String> _wordsFor(String module) {
    final raw = rulesBox.get(module);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  void _saveWords(String module, List<String> words) {
    rulesBox.put(module, words);
    setState(() {});
  }

  void _addWord(String module) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adicionar palavra — $module'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: mercado',
            helperText: 'Pode ser parte de uma palavra (ex: "almoç" detecta "almoço")',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final word = ctrl.text.trim().toLowerCase();
              if (word.isNotEmpty) {
                final words = _wordsFor(module);
                if (!words.contains(word)) {
                  words.add(word);
                  _saveWords(module, words);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _editWord(String module, int index, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar palavra — $module'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nova palavra ou trecho'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final word = ctrl.text.trim().toLowerCase();
              if (word.isNotEmpty) {
                final words = _wordsFor(module);
                words[index] = word;
                _saveWords(module, words);
              }
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteWord(String module, int index) {
    final words = _wordsFor(module);
    words.removeAt(index);
    _saveWords(module, words);
  }

  void _resetModule(String module) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Restaurar padrões — $module'),
        content: const Text('Isso substituirá todas as palavras pelas padrões do sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final defaults = _defaults[module] ?? [];
              _saveWords(module, List<String>.from(defaults));
              Navigator.pop(context);
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = _selectedModule ?? '';
    final words  = _wordsFor(module);
    final hasDefaults = _defaults.containsKey(module);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regras de detecção'),
        actions: [
          if (hasDefaults)
            IconButton(
              tooltip: 'Restaurar padrões',
              icon: const Icon(Icons.restore),
              onPressed: () => _resetModule(module),
            ),
          IconButton(
            tooltip: 'Adicionar palavra',
            icon: const Icon(Icons.add),
            onPressed: () => _addWord(module),
          ),
        ],
      ),
      body: Column(
        children: [
          // seletor de módulo
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: _selectedModule,
              decoration: const InputDecoration(
                labelText: 'Módulo',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _modules
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedModule = v),
            ),
          ),

          // cabeçalho
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Se o texto digitado contiver qualquer uma dessas palavras, o módulo "$module" será sugerido.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
            ]),
          ),

          const Divider(),

          // lista de palavras
          Expanded(
            child: words.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.search_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('Nenhuma palavra definida para "$module"',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _addWord(module),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar palavra'),
                      ),
                    ]),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: words.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      final updated = List<String>.from(words);
                      final moved = updated.removeAt(oldIndex);
                      updated.insert(newIndex, moved);
                      _saveWords(module, updated);
                    },
                    itemBuilder: (context, i) {
                      final word = words[i];
                      return ListTile(
                        key: ValueKey('$module-$i-$word'),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                        title: Text(word,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                        subtitle: Text(
                          'detecta: "${word}..." em qualquer posição',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () => _editWord(module, i, word),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remover',
                            onPressed: () => _deleteWord(module, i),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}