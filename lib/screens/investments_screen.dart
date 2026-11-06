import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({Key? key}) : super(key: key);

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final Box _investmentsBox = Hive.box('investments');
  final Box _investmentCategoriesBox =
      Hive.box('investment_categories');

  String _search = '';
  String? _selectedCategory;

  final List<String> _defaultCategories = [
    'Renda fixa',
    'Ações',
    'Fundos imobiliários',
    'ETFs',
    'Criptomoedas',
    'Previdência',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _ensureDefaultCategories();
  }

  void _ensureDefaultCategories() {
    if (_investmentCategoriesBox.isEmpty) {
      for (final category in _defaultCategories) {
        _investmentCategoriesBox.add(category);
      }
    }
  }

  List<String> _investmentCategories() {
    final categories = <String>{};

    for (final value in _investmentCategoriesBox.values) {
      if (value is String && value.trim().isNotEmpty) {
        categories.add(value.trim());
      }
    }

    final result = categories.toList();

    result.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0.0;
  }

  String _money(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return 'Sem data';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  List<Map<String, dynamic>> _allInvestments() {
    final result = <Map<String, dynamic>>[];

    for (final key in _investmentsBox.keys) {
      final raw = _investmentsBox.get(key);

      if (raw is Map) {
        final item = Map<String, dynamic>.from(raw);
        item['_key'] = key;
        result.add(item);
      }
    }

    result.sort((a, b) {
      final nameA = (a['name'] as String? ?? '').toLowerCase();
      final nameB = (b['name'] as String? ?? '').toLowerCase();

      return nameA.compareTo(nameB);
    });

    return result;
  }

  List<Map<String, dynamic>> _filteredInvestments() {
    final search = _search.trim().toLowerCase();

    return _allInvestments().where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final institution =
          (item['institution'] as String? ?? '').toLowerCase();
      final ticker = (item['ticker'] as String? ?? '').toLowerCase();
      final category = item['category'] as String? ?? 'Outros';

      final matchesSearch = search.isEmpty ||
          name.contains(search) ||
          institution.contains(search) ||
          ticker.contains(search);

      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'Todos' ||
          category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  double _totalInvested(
    List<Map<String, dynamic>> investments,
  ) {
    return investments.fold(
      0.0,
      (sum, item) => sum + _number(item['investedValue']),
    );
  }

  double _totalCurrent(
    List<Map<String, dynamic>> investments,
  ) {
    return investments.fold(
      0.0,
      (sum, item) => sum + _number(item['currentValue']),
    );
  }

  double _totalResult(
    List<Map<String, dynamic>> investments,
  ) {
    return _totalCurrent(investments) - _totalInvested(investments);
  }

  double _profitPercentage(
    List<Map<String, dynamic>> investments,
  ) {
    final invested = _totalInvested(investments);

    if (invested == 0) {
      return 0;
    }

    return (_totalResult(investments) / invested) * 100;
  }

  Future<String?> _showCategoryDialog({
    String? currentName,
  }) async {
    final controller = TextEditingController(
      text: currentName ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentName == null
                ? 'Nova categoria'
                : 'Editar categoria',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome da categoria',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _addInvestmentCategory() async {
    final name = await _showCategoryDialog();

    if (name == null || name.isEmpty) {
      return;
    }

    final alreadyExists = _investmentCategories().any(
      (category) => category.toLowerCase() == name.toLowerCase(),
    );

    if (alreadyExists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa categoria já existe'),
        ),
      );

      return;
    }

    await _investmentCategoriesBox.add(name);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editInvestmentCategory(
    dynamic categoryKey,
    String oldName,
  ) async {
    final newName = await _showCategoryDialog(
      currentName: oldName,
    );

    if (newName == null || newName.isEmpty) {
      return;
    }

    final alreadyExists = _investmentCategories().any(
      (category) =>
          category.toLowerCase() == newName.toLowerCase() &&
          category.toLowerCase() != oldName.toLowerCase(),
    );

    if (alreadyExists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa categoria já existe'),
        ),
      );

      return;
    }

    await _investmentCategoriesBox.put(
      categoryKey,
      newName,
    );

    for (final key in _investmentsBox.keys) {
      final raw = _investmentsBox.get(key);

      if (raw is Map && raw['category'] == oldName) {
        final updated = Map<String, dynamic>.from(raw);
        updated['category'] = newName;

        await _investmentsBox.put(key, updated);
      }
    }

    if (_selectedCategory == oldName) {
      _selectedCategory = newName;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteInvestmentCategory(
    dynamic categoryKey,
    String categoryName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir categoria?'),
          content: Text(
            'A categoria "$categoryName" será removida. '
            'Os investimentos dessa categoria serão movidos para '
            '"Outros".',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _investmentCategoriesBox.delete(categoryKey);

    for (final key in _investmentsBox.keys) {
      final raw = _investmentsBox.get(key);

      if (raw is Map && raw['category'] == categoryName) {
        final updated = Map<String, dynamic>.from(raw);
        updated['category'] = 'Outros';

        await _investmentsBox.put(key, updated);
      }
    }

    if (_selectedCategory == categoryName) {
      _selectedCategory = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showManageInvestmentCategories() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModal) {
            final categories = _investmentCategories();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        8,
                        8,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Categorias de investimentos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Nova categoria',
                            onPressed: () async {
                              await _addInvestmentCategory();
                              setModal(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: categories.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhuma categoria cadastrada',
                              ),
                            )
                          : ListView.separated(
                              itemCount: categories.length,
                              separatorBuilder: (_, __) {
                                return const Divider(height: 1);
                              },
                              itemBuilder: (_, index) {
                                final category = categories[index];

                                dynamic categoryKey;

                                for (final key
                                    in _investmentCategoriesBox.keys) {
                                  if (_investmentCategoriesBox.get(key) ==
                                      category) {
                                    categoryKey = key;
                                    break;
                                  }
                                }

                                return ListTile(
                                  title: Text(category),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        tooltip: 'Editar categoria',
                                        onPressed: categoryKey == null
                                            ? null
                                            : () async {
                                                await _editInvestmentCategory(
                                                  categoryKey,
                                                  category,
                                                );

                                                setModal(() {});
                                              },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Excluir categoria',
                                        onPressed: categoryKey == null
                                            ? null
                                            : () async {
                                                await _deleteInvestmentCategory(
                                                  categoryKey,
                                                  category,
                                                );

                                                setModal(() {});
                                              },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showInvestmentForm({
    Map<String, dynamic>? existing,
    dynamic hiveKey,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );

    final institutionController = TextEditingController(
      text: existing?['institution'] as String? ?? '',
    );

    final tickerController = TextEditingController(
      text: existing?['ticker'] as String? ?? '',
    );

    final investedController = TextEditingController(
      text: existing != null
          ? _number(existing['investedValue']).toStringAsFixed(2)
          : '',
    );

    final currentController = TextEditingController(
      text: existing != null
          ? _number(existing['currentValue']).toStringAsFixed(2)
          : '',
    );

    final quantityController = TextEditingController(
      text: existing != null
          ? _number(existing['quantity']).toString()
          : '',
    );

    final notesController = TextEditingController(
      text: existing?['notes'] as String? ?? '',
    );

    final categories = _investmentCategories();

    String category = existing?['category'] as String? ?? '';

    if (!categories.contains(category)) {
      category = categories.isNotEmpty ? categories.first : 'Outros';
    }

    DateTime selectedDate =
        _parseDate(existing?['updatedAt']) ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModal) {
            final currentCategories = _investmentCategories();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        existing == null
                            ? 'Novo investimento'
                            : 'Editar investimento',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do investimento',
                          hintText: 'Ex: Tesouro Selic 2029',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: institutionController,
                        decoration: const InputDecoration(
                          labelText: 'Instituição ou corretora',
                          hintText: 'Ex: XP, Nubank, Rico',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tickerController,
                        textCapitalization:
                            TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código ou ticker',
                          hintText: 'Ex: PETR4, MXRF11',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: currentCategories.contains(category)
                            ? category
                            : null,
                        items: currentCategories
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModal(() {
                            category = value ?? 'Outros';
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: investedController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Valor aplicado',
                                prefixText: 'R\$ ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: currentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Valor atual',
                                prefixText: 'R\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: quantityController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          hintText: 'Opcional',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            'Atualizado em ${_formatDate(selectedDate)}',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: modalContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setModal(() {
                                selectedDate = picked;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(modalContext);
                              },
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final name =
                                    nameController.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Informe o nome do investimento',
                                      ),
                                    ),
                                  );

                                  return;
                                }

                                final invested = double.tryParse(
                                      investedController.text
                                          .replaceAll(',', '.'),
                                    ) ??
                                    0.0;

                                final current = double.tryParse(
                                      currentController.text
                                          .replaceAll(',', '.'),
                                    ) ??
                                    invested;

                                final quantity = double.tryParse(
                                      quantityController.text
                                          .replaceAll(',', '.'),
                                    ) ??
                                    0.0;

                                final id = hiveKey ??
                                    DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();

                                final investment = {
                                  'id': id,
                                  'name': name,
                                  'institution':
                                      institutionController.text.trim(),
                                  'ticker': tickerController.text
                                      .trim()
                                      .toUpperCase(),
                                  'category': category,
                                  'investedValue': invested,
                                  'currentValue': current,
                                  'quantity': quantity,
                                  'notes': notesController.text.trim(),
                                  'updatedAt':
                                      selectedDate.toIso8601String(),
                                  'createdAt': existing?['createdAt'] ??
                                      DateTime.now()
                                          .toIso8601String(),
                                };

                                _investmentsBox.put(id, investment);

                                Navigator.pop(modalContext);
                                setState(() {});
                              },
                              child: Text(
                                existing == null
                                    ? 'Adicionar'
                                    : 'Salvar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    institutionController.dispose();
    tickerController.dispose();
    investedController.dispose();
    currentController.dispose();
    quantityController.dispose();
    notesController.dispose();
  }

  Future<void> _showTransactionForm(
    Map<String, dynamic> investment,
  ) async {
    final amountController = TextEditingController();
    String type = 'Aporte';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    type == 'Aporte'
                        ? 'Registrar aporte'
                        : 'Registrar resgate',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    investment['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'Aporte',
                        child: Text('Aporte'),
                      ),
                      DropdownMenuItem(
                        value: 'Resgate',
                        child: Text('Resgate'),
                      ),
                    ],
                    onChanged: (value) {
                      setModal(() {
                        type = value ?? 'Aporte';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipo de movimentação',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(modalContext);
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final amount = double.tryParse(
                                  amountController.text
                                      .replaceAll(',', '.'),
                                ) ??
                                0.0;

                            if (amount <= 0) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Informe um valor maior que zero',
                                  ),
                                ),
                              );

                              return;
                            }

                            final invested =
                                _number(investment['investedValue']);

                            final current =
                                _number(investment['currentValue']);

                            final updatedInvested = type == 'Aporte'
                                ? invested + amount
                                : invested - amount;

                            final updatedCurrent = type == 'Aporte'
                                ? current + amount
                                : current - amount;

                            final updated =
                                Map<String, dynamic>.from(investment);

                            updated['investedValue'] =
                                updatedInvested < 0
                                    ? 0.0
                                    : updatedInvested;

                            updated['currentValue'] = updatedCurrent < 0
                                ? 0.0
                                : updatedCurrent;

                            updated['updatedAt'] =
                                DateTime.now().toIso8601String();

                            updated.remove('_key');

                            _investmentsBox.put(
                              investment['_key'],
                              updated,
                            );

                            Navigator.pop(modalContext);
                            setState(() {});

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  type == 'Aporte'
                                      ? 'Aporte registrado'
                                      : 'Resgate registrado',
                                ),
                              ),
                            );
                          },
                          child: const Text('Registrar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  Future<void> _showInvestmentDetails(
    Map<String, dynamic> investment,
  ) async {
    final invested = _number(investment['investedValue']);
    final current = _number(investment['currentValue']);
    final result = current - invested;
    final percentage = invested == 0 ? 0.0 : result / invested * 100;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        investment['name'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${investment['category'] ?? 'Outros'}'
                  '${(investment['ticker'] as String? ?? '').isNotEmpty ? ' • ${investment['ticker']}' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(height: 24),
                _detailRow(
                  'Instituição',
                  investment['institution'] as String? ??
                      'Não informada',
                ),
                _detailRow(
                  'Valor aplicado',
                  _money(invested),
                ),
                _detailRow(
                  'Valor atual',
                  _money(current),
                ),
                _detailRow(
                  'Resultado',
                  _money(result),
                  valueColor:
                      result >= 0 ? Colors.green[700] : Colors.red[700],
                ),
                _detailRow(
                  'Rentabilidade',
                  '${percentage.toStringAsFixed(2)}%',
                  valueColor: percentage >= 0
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
                _detailRow(
                  'Quantidade',
                  _number(investment['quantity']).toString(),
                ),
                _detailRow(
                  'Atualizado em',
                  _formatDate(investment['updatedAt']),
                ),
                if ((investment['notes'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Observações',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(investment['notes'] as String),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Movimentar'),
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _showTransactionForm(investment);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _showInvestmentForm(
                            existing: investment,
                            hiveKey: investment['_key'],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    Map<String, dynamic> investment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir investimento?'),
          content: Text(
            'Deseja excluir "${investment['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _investmentsBox.delete(investment['_key']);

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investimento excluído'),
          ),
        );
      }
    }
  }

  Widget _summaryCard({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investimentos'),
        actions: [
          IconButton(
            tooltip: 'Categorias',
            icon: const Icon(Icons.category_outlined),
            onPressed: _showManageInvestmentCategories,
          ),
          IconButton(
            tooltip: 'Adicionar investimento',
            icon: const Icon(Icons.add),
            onPressed: () => _showInvestmentForm(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInvestmentForm(),
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: _investmentsBox.listenable(),
        builder: (context, Box box, _) {
          final investments = _filteredInvestments();

          final invested = _totalInvested(investments);
          final current = _totalCurrent(investments);
          final result = _totalResult(investments);
          final percentage = _profitPercentage(investments);

          final categories = [
            'Todos',
            ..._investmentCategories(),
          ];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _summaryCard(
                                    label: 'Aplicado',
                                    value: _money(invested),
                                  ),
                                  _summaryCard(
                                    label: 'Atual',
                                    value: _money(current),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  _summaryCard(
                                    label: 'Resultado',
                                    value: _money(result),
                                    valueColor: result >= 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                  _summaryCard(
                                    label: 'Rentabilidade',
                                    value:
                                        '${percentage.toStringAsFixed(2)}%',
                                    valueColor: percentage >= 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar investimento...',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _search = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: categories.map((category) {
                            final selected =
                                (_selectedCategory ?? 'Todos') ==
                                    category;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: selected,
                                selectedColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : null,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedCategory =
                                        category == 'Todos'
                                            ? null
                                            : category;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (investments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Nenhum investimento encontrado.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final investment = investments[index];

                        final investedValue =
                            _number(investment['investedValue']);
                        final currentValue =
                            _number(investment['currentValue']);
                        final result = currentValue - investedValue;
                        final percentage = investedValue == 0
                            ? 0.0
                            : result / investedValue * 100;

                        final ticker =
                            investment['ticker'] as String? ?? '';
                        final institution =
                            investment['institution'] as String? ?? '';

                        return Dismissible(
                          key: Key(
                            'investment_${investment['_key']}',
                          ),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.redAccent,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await _confirmDelete(investment);
                            return false;
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  investment['category'] == 'Ações'
                                      ? Icons.show_chart
                                      : Icons.account_balance,
                                ),
                              ),
                              title: Text(
                                investment['name'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(
                                    '${investment['category'] ?? 'Outros'}'
                                    '${ticker.isNotEmpty ? ' • $ticker' : ''}',
                                  ),
                                  if (institution.isNotEmpty)
                                    Text(
                                      institution,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Aplicado: ${_money(investedValue)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(currentValue),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${percentage >= 0 ? '+' : ''}'
                                    '${percentage.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: percentage >= 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showInvestmentDetails(investment);
                              },
                              onLongPress: () {
                                _showInvestmentForm(
                                  existing: investment,
                                  hiveKey: investment['_key'],
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: investments.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}