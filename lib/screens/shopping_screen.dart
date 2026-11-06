// lib/screens/shopping_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/supabase_service.dart';

const String kShoppingProductsBox = 'alfred_shopping_products';
const String kShoppingListBox = 'alfred_shopping_list';
const String kShoppingSavedBox = 'alfred_shopping_saved';

// Guarda ids apagados de propósito, para o sync do outro
// aparelho nunca "ressuscitar" o que o usuário excluiu.
const String kShoppingTombstonesBox = 'alfred_shopping_tombstones';

// Unidades que aceitam quantidade fracionada (passo 0,1 nos botões ±).
const List<String> kFractionalUnits = ['kg', 'g', 'l', 'litro', 'litros', 'ml'];

final RegExp _qtyPriceChars = RegExp(r'[0-9.,]');

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

String _money(double v) {
  final isNegative = v < 0;
  final s = v.abs().toStringAsFixed(2).replaceAll('.', ',');
  return '${isNegative ? '-' : ''}R\$ $s';
}

/// 2 → "2"; 1.4 → "1,4"; 1.32 → "1,32"
String _fmtQty(double q) {
  final rounded = double.parse(q.toStringAsFixed(3));
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  String s = rounded.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s.replaceAll('.', ',');
}

/// Normaliza para busca/ordenação (ignora maiúsculas e acentos).
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('à', 'a')
    .replaceAll('ã', 'a')
    .replaceAll('â', 'a')
    .replaceAll('é', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ô', 'o')
    .replaceAll('õ', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

bool _isFractionalUnit(String unit) =>
    kFractionalUnits.contains(unit.trim().toLowerCase());

double _stepFor(String unit) => _isFractionalUnit(unit) ? 0.1 : 1.0;

// Chave de deduplicação: registros idênticos criados nos dois
// aparelhos (mesmo nome, unidade e preço) colapsam em um só.
String _prodKey(String name, String unit, double price) =>
    '${_norm(name)}|${_norm(unit)}|${price.toStringAsFixed(2)}';

String _itemKey(String name, String unit, double price) =>
    '${_norm(name)}|${_norm(unit)}|${price.toStringAsFixed(2)}';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({Key? key}) : super(key: key);

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  late Future<void> _boxesReady;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Campo de quantidade embutido em cada linha da lista.
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _boxesReady = _openBoxes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    for (final n in _qtyFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _openBoxes() async {
    if (!Hive.isBoxOpen(kShoppingProductsBox)) {
      await Hive.openBox(kShoppingProductsBox);
    }
    if (!Hive.isBoxOpen(kShoppingListBox)) {
      await Hive.openBox(kShoppingListBox);
    }
    if (!Hive.isBoxOpen(kShoppingSavedBox)) {
      await Hive.openBox(kShoppingSavedBox);
    }
    if (!Hive.isBoxOpen(kShoppingTombstonesBox)) {
      await Hive.openBox(kShoppingTombstonesBox);
    }

    // Sincroniza com a nuvem em segundo plano; a UI abre
    // imediatamente com os dados locais e atualiza sozinha.
    unawaited(_syncFromCloud());
  }

  Box get _productsBox => Hive.box(kShoppingProductsBox);

  Box get _listBox => Hive.box(kShoppingListBox);

  Box get _savedBox => Hive.box(kShoppingSavedBox);

  // ── Túmulos (ids apagados não voltam pelo sync) ──

  Future<void> _tombstone(String id) async {
    try {
      if (!Hive.isBoxOpen(kShoppingTombstonesBox)) {
        await Hive.openBox(kShoppingTombstonesBox);
      }
      await Hive.box(kShoppingTombstonesBox)
          .put(id, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  void _untombstone(String id) {
    try {
      if (!Hive.isBoxOpen(kShoppingTombstonesBox)) return;
      Hive.box(kShoppingTombstonesBox).delete(id);
    } catch (_) {}
  }

  bool _isTombstoned(String id) {
    try {
      if (!Hive.isBoxOpen(kShoppingTombstonesBox)) return false;
      return Hive.box(kShoppingTombstonesBox).get(id) != null;
    } catch (_) {
      return false;
    }
  }

  // ── Nuvem (Supabase): escrita espelhada + merge na abertura ──

  String? get _userId {
    try {
      return SupabaseService.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String _newId() {
    final rnd = Random();
    final suffix =
        List.generate(4, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${DateTime.now().microsecondsSinceEpoch}$suffix';
  }

  List<Map<String, dynamic>> _rowsOf(dynamic res) {
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> _cloudUpsertProduct(Map<String, dynamic> product) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('shopping_products').upsert({
        'id': product['id'].toString(),
        'user_id': uid,
        'name': product['name'].toString(),
        'unit': (product['unit'] ?? '').toString(),
        'price': _asDouble(product['price']),
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Offline ou erro: fica só no local.
    }
  }

  Future<void> _cloudDeleteProduct(String id) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('shopping_products')
          .delete()
          .eq('id', id)
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _cloudUpsertListItem(Map<String, dynamic> item) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('shopping_list_items').upsert({
        'id': item['id'].toString(),
        'user_id': uid,
        'product_id': (item['productId'] ?? '').toString(),
        'name': item['name'].toString(),
        'unit': (item['unit'] ?? '').toString(),
        'price': _asDouble(item['price']),
        'quantity': _asDouble(item['quantity']),
        'is_bought': item['isBought'] == true,
      }).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _cloudDeleteListItem(String id) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('shopping_list_items')
          .delete()
          .eq('id', id)
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _cloudUpsertSavedList(
      String dayKey, Map<String, dynamic> snapshot) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('shopping_saved_lists').upsert({
        'id': dayKey,
        'user_id': uid,
        'day': dayKey,
        'items': snapshot['items'] ?? [],
        'total': _asDouble(snapshot['total']),
        'units': snapshot['units'] is num
            ? (snapshot['units'] as num).toInt()
            : 0,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _cloudDeleteSavedList(String dayKey) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('shopping_saved_lists')
          .delete()
          .eq('id', dayKey)
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _syncFromCloud() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final productsRes = await SupabaseService.client
          .from('shopping_products')
          .select()
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));

      final listRes = await SupabaseService.client
          .from('shopping_list_items')
          .select()
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));

      final savedRes = await SupabaseService.client
          .from('shopping_saved_lists')
          .select()
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      await _mergeProducts(_rowsOf(productsRes));
      await _mergeListItems(_rowsOf(listRes));
      await _mergeSavedLists(_rowsOf(savedRes));
    } catch (_) {
      // Offline: segue com os dados locais.
    }
  }

  // ── Merge com deduplicação (dono = menor id, igual nos 2 aparelhos) ──

  Future<void> _mergeProducts(List<Map<String, dynamic>> rows) async {
    final candidates = <String, Map<String, dynamic>>{};
    final cloudIds = <String>{};
    final junkCloudIds = <String>{};

    for (final row in rows) {
      final id = row['id'].toString();
      final name = (row['name'] ?? '').toString();

      if (name.trim().isEmpty) {
        junkCloudIds.add(id);
        continue;
      }
      cloudIds.add(id);

      final k = _prodKey(
          name, (row['unit'] ?? '').toString(), _asDouble(row['price']));
      final cur = candidates[k];
      if (cur == null || id.compareTo(cur['id'] as String) < 0) {
        candidates[k] = {
          'id': id,
          'name': name,
          'unit': (row['unit'] ?? '').toString(),
          'price': _asDouble(row['price']),
        };
      }
    }

    final localIds = <String>{};
    for (final key in _productsBox.keys.toList()) {
      final raw = _productsBox.get(key);
      if (raw is! Map) continue;

      final local = Map<String, dynamic>.from(raw);
      final name = _nameOf(local);
      if (name.trim().isEmpty) {
        await _productsBox.delete(key);
        continue;
      }

      final id = key.toString();
      localIds.add(id);

      final k = _prodKey(name, (local['unit'] ?? '').toString(),
          _asDouble(local['price']));
      final cur = candidates[k];
      if (cur == null || id.compareTo(cur['id'] as String) < 0) {
        candidates[k] = {
          'id': id,
          'name': name,
          'unit': (local['unit'] ?? '').toString(),
          'price': _asDouble(local['price']),
        };
      }
    }

    // Garante o dono de cada chave no local e na nuvem.
    for (final cand in candidates.values) {
      final id = cand['id'].toString();

      if (_isTombstoned(id)) {
        // Apagado pelo usuário antes → não deixa ressuscitar.
        if (localIds.contains(id)) await _productsBox.delete(id);
        unawaited(_cloudDeleteProduct(id));
        continue;
      }

      final keep = {
        'id': id,
        'name': cand['name'],
        'unit': cand['unit'],
        'price': _asDouble(cand['price']),
      };

      final localRaw = _productsBox.get(id);
      if (localRaw is! Map ||
          _nameOf(Map<String, dynamic>.from(localRaw)).trim().isEmpty) {
        await _productsBox.put(id, keep);
      }

      if (!cloudIds.contains(id)) {
        unawaited(_cloudUpsertProduct(keep));
      }
    }

    // Remove duplicados do local (e religa os itens da lista).
    for (final key in _productsBox.keys.toList()) {
      final raw = _productsBox.get(key);
      if (raw is! Map) continue;

      final local = Map<String, dynamic>.from(raw);
      final id = key.toString();
      final k = _prodKey(_nameOf(local), (local['unit'] ?? '').toString(),
          _asDouble(local['price']));
      final owner = candidates[k];

      if (owner == null || owner['id'].toString() != id) {
        await _productsBox.delete(key);
        await _tombstone(id);
        unawaited(_cloudDeleteProduct(id));

        if (owner != null) {
          await _relinkListItems(
            oldProductId: id,
            newProductId: owner['id'].toString(),
          );
        }
      }
    }

    // Remove duplicados que ainda estão na nuvem.
    for (final row in rows) {
      final id = row['id'].toString();
      final name = (row['name'] ?? '').toString();

      if (name.trim().isEmpty || junkCloudIds.contains(id)) {
        unawaited(_cloudDeleteProduct(id));
        continue;
      }

      final k = _prodKey(
          name, (row['unit'] ?? '').toString(), _asDouble(row['price']));
      final owner = candidates[k];
      if (owner == null || owner['id'].toString() != id) {
        unawaited(_cloudDeleteProduct(id));
      }
    }
  }

  /// Itens da lista apontavam para um produto duplicado que foi
  /// removido → religa para o produto que ficou.
  Future<void> _relinkListItems({
    required String oldProductId,
    required String newProductId,
  }) async {
    for (final key in _listBox.keys.toList()) {
      final raw = _listBox.get(key);
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);
      if ((item['productId'] ?? '').toString() != oldProductId) continue;

      item['productId'] = newProductId;
      await _listBox.put(key, item);
      unawaited(_cloudUpsertListItem(item));
    }
  }

  Future<void> _mergeListItems(List<Map<String, dynamic>> rows) async {
    final candidates = <String, Map<String, dynamic>>{};
    final cloudIds = <String>{};
    final junkCloudIds = <String>{};

    for (final row in rows) {
      final id = row['id'].toString();
      final name = (row['name'] ?? '').toString();

      if (name.trim().isEmpty) {
        junkCloudIds.add(id);
        continue;
      }
      cloudIds.add(id);

      final k = _itemKey(
          name, (row['unit'] ?? '').toString(), _asDouble(row['price']));
      final cur = candidates[k];
      if (cur == null || id.compareTo(cur['id'] as String) < 0) {
        candidates[k] = {
          'id': id,
          'productId': (row['product_id'] ?? '').toString(),
          'name': name,
          'unit': (row['unit'] ?? '').toString(),
          'price': _asDouble(row['price']),
          'quantity': _asDouble(row['quantity']),
          'isBought': row['is_bought'] == true,
        };
      }
    }

    final localIds = <String>{};
    for (final key in _listBox.keys.toList()) {
      final raw = _listBox.get(key);
      if (raw is! Map) continue;

      final local = Map<String, dynamic>.from(raw);
      final name = _nameOf(local);
      if (name.trim().isEmpty) {
        await _listBox.delete(key);
        unawaited(_cloudDeleteListItem(key.toString()));
        continue;
      }

      final id = key.toString();
      localIds.add(id);

      final k = _itemKey(name, (local['unit'] ?? '').toString(),
          _asDouble(local['price']));
      final cur = candidates[k];
      if (cur == null || id.compareTo(cur['id'] as String) < 0) {
        candidates[k] = {
          'id': id,
          'productId': (local['productId'] ?? '').toString(),
          'name': name,
          'unit': (local['unit'] ?? '').toString(),
          'price': _asDouble(local['price']),
          'quantity': _asDouble(local['quantity']),
          'isBought': local['isBought'] == true,
        };
      }
    }

    for (final cand in candidates.values) {
      final id = cand['id'].toString();

      if (_isTombstoned(id)) {
        if (localIds.contains(id)) await _listBox.delete(id);
        unawaited(_cloudDeleteListItem(id));
        continue;
      }

      final keep = {
        'id': id,
        'productId': (cand['productId'] ?? '').toString(),
        'name': cand['name'],
        'unit': cand['unit'],
        'price': _asDouble(cand['price']),
        'quantity': _asDouble(cand['quantity']),
        'isBought': cand['isBought'] == true,
      };

      final localRaw = _listBox.get(id);
      if (localRaw is! Map ||
          _nameOf(Map<String, dynamic>.from(localRaw)).trim().isEmpty) {
        await _listBox.put(id, keep);
      }

      if (!cloudIds.contains(id)) {
        unawaited(_cloudUpsertListItem(keep));
      }
    }

    // Remove duplicados do local.
    for (final key in _listBox.keys.toList()) {
      final raw = _listBox.get(key);
      if (raw is! Map) continue;

      final local = Map<String, dynamic>.from(raw);
      final id = key.toString();
      final k = _itemKey(_nameOf(local), (local['unit'] ?? '').toString(),
          _asDouble(local['price']));
      final owner = candidates[k];

      if (owner == null || owner['id'].toString() != id) {
        await _listBox.delete(key);
        await _tombstone(id);
        unawaited(_cloudDeleteListItem(id));
      }
    }

    // Remove duplicados que ainda estão na nuvem.
    for (final row in rows) {
      final id = row['id'].toString();
      final name = (row['name'] ?? '').toString();

      if (name.trim().isEmpty || junkCloudIds.contains(id)) {
        unawaited(_cloudDeleteListItem(id));
        continue;
      }

      final k = _itemKey(
          name, (row['unit'] ?? '').toString(), _asDouble(row['price']));
      final owner = candidates[k];
      if (owner == null || owner['id'].toString() != id) {
        unawaited(_cloudDeleteListItem(id));
      }
    }
  }

  Future<void> _mergeSavedLists(List<Map<String, dynamic>> rows) async {
    final cloudDays = <String>{};

    for (final row in rows) {
      final day = (row['day'] ?? row['id'] ?? '').toString();
      if (day.isEmpty) continue;

      if (_isTombstoned(day)) {
        unawaited(_cloudDeleteSavedList(day));
        continue;
      }

      cloudDays.add(day);

      // Só preenche o que não existe localmente; a escrita local
      // já sobe para a nuvem na hora do save.
      if (_savedBox.get(day) != null) continue;

      final itemsRaw = row['items'];
      final items = itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      await _savedBox.put(day, {
        'day': day,
        'items': items,
        'total': _asDouble(row['total']),
        'units': row['units'] is num
            ? (row['units'] as num).toInt()
            : items.length,
        'savedAt': (row['saved_at'] ?? '').toString(),
      });
    }

    for (final key in _savedBox.keys.toList()) {
      final keyStr = key.toString();

      if (_isTombstoned(keyStr)) {
        await _savedBox.delete(key);
        continue;
      }

      if (!cloudDays.contains(keyStr)) {
        final raw = _savedBox.get(key);
        if (raw is Map) {
          unawaited(_cloudUpsertSavedList(
              keyStr, Map<String, dynamic>.from(raw)));
        }
      }
    }
  }

  // ── Dados ──

  String _nameOf(Map<String, dynamic> m) => (m['name'] ?? '').toString();

  /// "1 kg coração de alcatra": unidade cadastrada + nome.
  String _titleOf(Map<String, dynamic> item) {
    final unit = (item['unit'] ?? '').toString().trim();
    final name = _nameOf(item);
    return unit.isEmpty ? name : '$unit $name';
  }

  List<Map<String, dynamic>> get _products {
    final rows = _productsBox.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    rows.sort((a, b) => _norm(_nameOf(a)).compareTo(_norm(_nameOf(b))));
    return rows;
  }

  List<Map<String, dynamic>> get _listItems {
    final rows = _listBox.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    // Ordem alfabética.
    rows.sort((a, b) => _norm(_nameOf(a)).compareTo(_norm(_nameOf(b))));
    return rows;
  }

  List<Map<String, dynamic>> get _savedLists {
    final rows = <Map<String, dynamic>>[];
    for (final key in _savedBox.keys.toList()) {
      final raw = _savedBox.get(key);
      if (raw is! Map) continue;
      final snap = Map<String, dynamic>.from(raw);
      snap['day'] = snap['day']?.toString() ?? key.toString();
      snap['_key'] = key;
      rows.add(snap);
    }
    rows.sort((a, b) =>
        (b['day'] ?? '').toString().compareTo((a['day'] ?? '').toString()));
    return rows;
  }

  Map<String, dynamic>? _listItemForProduct(dynamic productId) {
    final id = productId.toString();
    for (final raw in _listBox.values) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if ((item['productId'] ?? '').toString() == id) return item;
    }
    return null;
  }

  String _dayKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _labelOfDayKey(String dayKey) {
    final parts = dayKey.split('-');
    if (parts.length != 3) return dayKey;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── Stepper embutido (− [campo] +) ──

  FocusNode _focusNodeFor(String id) {
    return _qtyFocusNodes.putIfAbsent(id, () {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) {
          // Ao sair do campo, confirma o que foi digitado.
          final raw = _listBox.get(id);
          if (raw is Map) {
            _commitInlineQty(Map<String, dynamic>.from(raw));
          }
        }
      });
      return node;
    });
  }

  TextEditingController _ctrlFor(String id, double qty) {
    final ctrl = _qtyCtrls.putIfAbsent(
        id, () => TextEditingController(text: _fmtQty(qty)));

    // Só sobrescreve o texto se o campo NÃO estiver em foco
    // (para não interromper a digitação do usuário).
    final node = _qtyFocusNodes[id];
    final focused = node?.hasFocus ?? false;
    if (!focused &&
        _asDouble(ctrl.text).toStringAsFixed(3) != qty.toStringAsFixed(3)) {
      ctrl.text = _fmtQty(qty);
    }
    return ctrl;
  }

  void _onInlineQtyChanged(Map<String, dynamic> item) {
    final ctrl = _qtyCtrls[item['id'].toString()];
    if (ctrl == null) return;

    final v = _asDouble(ctrl.text);
    if (v > 0 && v != _asDouble(item['quantity'])) {
      _setQty(item, v);
    }
  }

  void _commitInlineQty(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final ctrl = _qtyCtrls[id];
    if (ctrl == null) return;

    final v = _asDouble(ctrl.text);
    final current = _asDouble(item['quantity']);

    if (v > 0 && v != current) {
      _setQty(item, v);
    } else if (v <= 0) {
      // Valor zerado/inválido digitado → restaura o anterior
      // (a retirada do item é pelos botões - ou pelo menu).
      ctrl.text = _fmtQty(current);
    }
  }

  Future<void> _bumpQty(Map<String, dynamic> item, double delta) async {
    final newQty = double.parse(
        (_asDouble(item['quantity']) + delta).toStringAsFixed(3));
    if (newQty <= 0) {
      await _removeFromList(item);
    } else {
      await _setQty(item, newQty);
    }
  }

  // ── Ações ──

  Future<void> _addToList(Map<String, dynamic> product) async {
    final item = {
      'id': _newId(),
      'productId': product['id'].toString(),
      'name': product['name'].toString(),
      'unit': (product['unit'] ?? '').toString(),
      'price': _asDouble(product['price']),
      'quantity': 1.0,
      'isBought': false,
    };
    await _listBox.put(item['id'], item);
    unawaited(_cloudUpsertListItem(item));
  }

  Future<void> _removeFromList(Map<String, dynamic> item) async {
    await _listBox.delete(item['id'].toString());
    await _tombstone(item['id'].toString());
    unawaited(_cloudDeleteListItem(item['id'].toString()));
  }

  Future<void> _toggleBought(Map<String, dynamic> item) async {
    final updated = Map<String, dynamic>.from(item);
    updated['isBought'] = !(item['isBought'] == true);
    await _listBox.put(updated['id'].toString(), updated);
    unawaited(_cloudUpsertListItem(updated));
  }

  Future<void> _setQty(Map<String, dynamic> item, double qty) async {
    final clean = double.parse(qty.toStringAsFixed(3));
    final updated = Map<String, dynamic>.from(item);
    updated['quantity'] = clean;
    await _listBox.put(updated['id'].toString(), updated);
    unawaited(_cloudUpsertListItem(updated));
  }

  Future<void> _saveProduct(Map<String, dynamic> product) async {
    await _productsBox.put(product['id'].toString(), product);
    unawaited(_cloudUpsertProduct(product));
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final item = _listItemForProduct(product['id']);
    if (item != null) await _removeFromList(item);

    await _productsBox.delete(product['id'].toString());
    await _tombstone(product['id'].toString());
    unawaited(_cloudDeleteProduct(product['id'].toString()));
  }

  Future<void> _showProductDialog(
      {Map<String, dynamic>? existingProduct}) async {
    final nameCtrl = TextEditingController(
        text: existingProduct?['name']?.toString() ?? '');
    final unitCtrl = TextEditingController(
        text: (existingProduct?['unit'] ?? '').toString());
    final priceCtrl = TextEditingController(
        text: existingProduct == null
            ? ''
            : _asDouble(existingProduct['price'])
                .toStringAsFixed(2)
                .replaceAll('.', ','));

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title:
            Text(existingProduct == null ? 'Novo produto' : 'Editar produto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: existingProduct == null,
              decoration:
                  const InputDecoration(labelText: 'Nome do produto'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unidade',
                hintText: 'Ex: 1 kg, 400 g, un, cx...',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(_qtyPriceChars),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor por unidade',
                hintText: 'Ex: 40,00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final product = {
                'id': existingProduct?['id']?.toString() ?? _newId(),
                'name': name,
                'unit': unitCtrl.text.trim(),
                'price': _asDouble(priceCtrl.text),
              };

              Navigator.pop(dialogCtx);
              _saveProduct(product);
            },
            child: Text(existingProduct == null ? 'Cadastrar' : 'Salvar'),
          ),
        ],
      ),
    );
  }

  /// Toque no item da lista: mesmo formulário do "Editar produto"
  /// (nome, unidade e valor). A quantidade NÃO se edita aqui —
  /// só pelo stepper − [campo] + da própria linha.
  Future<void> _showItemDialog(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: _nameOf(item));
    final unitCtrl =
        TextEditingController(text: (item['unit'] ?? '').toString());
    final priceCtrl = TextEditingController(
        text: _asDouble(item['price'])
            .toStringAsFixed(2)
            .replaceAll('.', ','));

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nome do produto'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unidade',
                hintText: 'Ex: 1 kg, 400 g, un, cx...',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(_qtyPriceChars),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor por unidade',
                hintText: 'Ex: 40,00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final updated = Map<String, dynamic>.from(item);
              updated['name'] = name;
              updated['unit'] = unitCtrl.text.trim();
              updated['price'] = _asDouble(priceCtrl.text);

              Navigator.pop(dialogCtx);
              _listBox.put(updated['id'].toString(), updated);
              unawaited(_cloudUpsertListItem(updated));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToDay() async {
    final items = _listItems;
    if (items.isEmpty) {
      _snack('A lista está vazia');
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Salvar lista em qual dia?',
    );
    if (picked == null) return;

    final dayKey = _dayKeyOf(picked);

    final snapshotItems = items.map((item) {
      final qty = _asDouble(item['quantity']);
      final unitPrice = _asDouble(item['price']);
      return {
        'name': _nameOf(item),
        'unit': (item['unit'] ?? '').toString(),
        'quantity': qty,
        'price': unitPrice,
        'lineTotal': unitPrice * qty,
        'isBought': item['isBought'] == true,
      };
    }).toList();

    final total = snapshotItems.fold<double>(
        0, (s, e) => s + (e['lineTotal'] as double));

    final snapshot = {
      'day': dayKey,
      'items': snapshotItems,
      'total': total,
      'units': items.length,
      'savedAt': DateTime.now().toIso8601String(),
    };

    // Se esse dia já tinha sido apagado, a nova gravação vale.
    _untombstone(dayKey);

    await _savedBox.put(dayKey, snapshot);
    unawaited(_cloudUpsertSavedList(dayKey, snapshot));

    _snack('Lista salva em ${_labelOfDayKey(dayKey)}');
  }

  Future<void> _confirmDeleteSavedList(Map<String, dynamic> snap) async {
    final dayKey = (snap['day'] ?? '').toString();
    final boxKey = snap['_key'] ?? dayKey;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remover lista salva'),
        content: Text(
            'Remover a lista do dia ${_labelOfDayKey(dayKey)}? O quadrado some da Home.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Apaga pela CHAVE real da box (não pelo campo day) —
    // registros antigos podiam ter chave diferente do dia.
    await _savedBox.delete(boxKey);

    await _tombstone(dayKey);
    if (boxKey.toString() != dayKey) await _tombstone(boxKey.toString());

    if (dayKey.isNotEmpty) unawaited(_cloudDeleteSavedList(dayKey));
  }

  /// Abre a lista salva: itens, quantidades, totais e botão excluir.
  Future<void> _openSavedList(Map<String, dynamic> snap) async {
    final dayKey = (snap['day'] ?? '').toString();
    final itemsRaw = snap['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    double total = 0;
    for (final it in items) {
      final lt = _asDouble(it['lineTotal']);
      total += lt != 0
          ? lt
          : _asDouble(it['price']) * _asDouble(it['quantity']);
    }

    final units = snap['units'] is num
        ? (snap['units'] as num).toInt()
        : items.length;

    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Lista de ${_labelOfDayKey(dayKey)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$units ${units == 1 ? 'item' : 'itens'} • ${_money(total)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Lista vazia.')),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final it = items[i];
                            final qty = _asDouble(it['quantity']);
                            final price = _asDouble(it['price']);
                            final lineTotal = _asDouble(it['lineTotal']) != 0
                                ? _asDouble(it['lineTotal'])
                                : qty * price;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _titleOf(it),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_fmtQty(qty)} x ${_money(price)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                _money(lineTotal),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dCtx);
              _confirmDeleteSavedList(snap);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boxesReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Compras')),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _productsBox.listenable(),
                _listBox.listenable(),
                _savedBox.listenable(),
              ]),
              builder: (context, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 8),
                      _buildCurrentList(),
                      const SizedBox(height: 12),
                      _buildSavedLists(),
                      const SizedBox(height: 12),
                      _buildProductCatalog(),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Buscar item na lista ou produto...',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
      ),
    );
  }

  bool _matches(String? name) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return _norm(name ?? '').contains(_norm(q));
  }

  void _cleanupCtrls(Set<String> liveIds) {
    for (final id in _qtyCtrls.keys.toList()) {
      if (!liveIds.contains(id)) {
        _qtyCtrls.remove(id)?.dispose();
      }
    }
    for (final id in _qtyFocusNodes.keys.toList()) {
      if (!liveIds.contains(id)) {
        _qtyFocusNodes.remove(id)?.dispose();
      }
    }
  }

  Widget _buildCurrentList() {
    final items = _listItems;
    final visible =
        items.where((it) => _matches(_nameOf(it))).toList();

    // Soma de TODOS os itens (o fold antigo tinha um bug que
    // descartava o acumulador e sobrava só o último item).
    final total = items.fold<double>(
        0, (s, it) => s + _asDouble(it['price']) * _asDouble(it['quantity']));

    // Libera controllers/focus de itens que saíram da lista.
    final liveIds = items.map((e) => e['id'].toString()).toSet();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _cleanupCtrls(liveIds));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lista atual',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${items.length} ${items.length == 1 ? 'item' : 'itens'} • ${_money(total)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Salvar lista em um dia',
                    icon: const Icon(Icons.save_outlined),
                    onPressed: _saveToDay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Adicione produtos pelo catálogo abaixo.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nenhum item encontrado para "$_query".',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...visible.map(_buildListItem),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final unit = (item['unit'] ?? '').toString().trim();
    final qty = _asDouble(item['quantity']);
    final price = _asDouble(item['price']);
    final lineTotal = price * qty;
    final bought = item['isBought'] == true;
    final step = _stepFor(unit);
    final bigStep = _isFractionalUnit(unit) ? 1.0 : 10.0;

    final focusNode = _focusNodeFor(id);
    final ctrl = _ctrlFor(id, qty);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: Checkbox(
              value: bought,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => _toggleBought(item),
            ),
          ),
          Expanded(
            // Toque no texto abre o formulário de nome/unidade/valor
            // (igual ao "Editar produto"). Sem quantidade aqui.
            child: InkWell(
              onTap: () => _showItemDialog(item),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "1 kg coração de alcatra" (unidade cadastrada + nome)
                    Text(
                      _titleOf(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            bought ? TextDecoration.lineThrough : null,
                        color: bought ? Colors.grey : null,
                      ),
                    ),
                    // "1,32 x R$ 55,98"
                    Text(
                      '${_fmtQty(qty)} x ${_money(price)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    // Total do item
                    Text(
                      _money(lineTotal),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 30,
            width: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'Diminuir (segure p/ -1)',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _bumpQty(item, -step),
              onLongPress: () => _bumpQty(item, -bigStep),
            ),
          ),
          // Campo de quantidade compacto (cabe "1,53").
          Tooltip(
            message: 'Quantidade — pode digitar fração, ex: 1,32',
            child: SizedBox(
              width: 48,
              child: TextField(
                controller: ctrl,
                focusNode: focusNode,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_qtyPriceChars),
                ],
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _onInlineQtyChanged(item),
                onSubmitted: (_) => _commitInlineQty(item),
              ),
            ),
          ),
          SizedBox(
            height: 30,
            width: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'Aumentar (segure p/ +1)',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _bumpQty(item, step),
              onLongPress: () => _bumpQty(item, bigStep),
            ),
          ),
          SizedBox(
            height: 30,
            width: 30,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (value) {
                if (value == 'edit') {
                  _showItemDialog(item);
                } else if (value == 'remove') {
                  _removeFromList(item);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar item'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Retirar da lista'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedLists() {
    final saved = _savedLists;
    if (saved.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Listas salvas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Toque em uma lista para abrir os itens.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            ...saved.map(_buildSavedRow),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedRow(Map<String, dynamic> snap) {
    final dayKey = (snap['day'] ?? snap['_key'] ?? '').toString();
    final total = _asDouble(snap['total']);
    final units = snap['units'] is num ? (snap['units'] as num).toInt() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            // Toque abre a lista salva (itens + total + excluir).
            child: InkWell(
              onTap: () => _openSavedList(snap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelOfDayKey(dayKey),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$units ${units == 1 ? 'item' : 'itens'} • ${_money(total)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              tooltip: 'Remover lista salva',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDeleteSavedList(snap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog() {
    final products = _products;
    final visible =
        products.where((p) => _matches(_nameOf(p))).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Produtos cadastrados',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Novo produto',
                    icon: const Icon(Icons.add),
                    onPressed: () => _showProductDialog(),
                  ),
                ),
              ],
            ),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhum produto cadastrado.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nenhum produto encontrado para "$_query".',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...visible.map(_buildCatalogProduct),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogProduct(Map<String, dynamic> product) {
    final item = _listItemForProduct(product['id']);
    final isInList = item != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product['unit']} • ${_money(_asDouble(product['price']))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              tooltip: isInList ? 'Retirar da lista' : 'Adicionar à lista',
              icon: Icon(
                isInList
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.add_shopping_cart_outlined,
                color: isInList ? Colors.redAccent : Colors.green,
              ),
              onPressed: () {
                if (isInList) {
                  _removeFromList(item);
                } else {
                  _addToList(product);
                }
              },
            ),
          ),
          SizedBox(
            height: 32,
            width: 32,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 20,
              onSelected: (value) {
                if (value == 'edit') {
                  _showProductDialog(existingProduct: product);
                } else if (value == 'delete') {
                  _deleteProduct(product);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar produto'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir produto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}