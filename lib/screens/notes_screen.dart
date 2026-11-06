import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const String _boxName = 'alfred_daily_notes';
  static const String _noteKey = 'anotacoes_gerais';

  late final TextEditingController _controller;
  Box? _notesBox;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final notesBox = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);

    if (!mounted) return;

    setState(() {
      _notesBox = notesBox;
      _controller.text = notesBox.get(_noteKey)?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _saveNote({bool showMessage = true}) async {
    final notesBox = _notesBox;
    if (notesBox == null || _saving) return;

    setState(() => _saving = true);

    final text = _controller.text;
    if (text.trim().isEmpty) {
      await notesBox.delete(_noteKey);
    } else {
      await notesBox.put(_noteKey, text);
    }

    if (!mounted) return;

    setState(() => _saving = false);

    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anotação salva')),
      );
    }
  }

  Future<bool> _handleBack() async {
    await _saveNote(showMessage: false);
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anotações'),
          actions: [
            TextButton.icon(
              onPressed: _loading || _saving ? null : () => _saveNote(),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Escreva suas anotações...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
      ),
    );
  }
}