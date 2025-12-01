import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class EditInventoryItemScreen extends StatefulWidget {
  // تم التغيير إلى Map لدعم البيانات القادمة من API
  final Map<String, dynamic>? item;
  const EditInventoryItemScreen({super.key, this.item});

  @override
  State<EditInventoryItemScreen> createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
  final ApiService _apiService = ApiService();
  late AppLocalizations l10n;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalQuantityController = TextEditingController();
  bool get _isEditing => widget.item != null;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.item!['name'];
      _totalQuantityController.text = widget.item!['totalQuantity'].toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalQuantityController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final totalQuantity = int.tryParse(_totalQuantityController.text) ?? 0;

    try {
      if (_isEditing) {
        // عند التعديل، نحتاج لتحديث الكمية المتاحة أيضاً
        final oldTotal = widget.item!['totalQuantity'] as int;
        final oldAvailable = widget.item!['availableQuantity'] as int;

        // حساب الفارق وإضافته للكمية المتاحة
        final diff = totalQuantity - oldTotal;
        final newAvailable = oldAvailable + diff;

        await _apiService.updateInventoryItem(widget.item!['id'], {
          'name': _nameController.text,
          'totalQuantity': totalQuantity,
          'availableQuantity': newAvailable < 0 ? 0 : newAvailable,
        });
      } else {
        // عند الإضافة، الكمية المتاحة تساوي الكمية الإجمالية
        await _apiService.addInventoryItem({
          'name': _nameController.text,
          'totalQuantity': totalQuantity,
          'availableQuantity': totalQuantity,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Error saving inventory item: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.editInventoryItem : l10n.addInventoryItem,
        ),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveItem),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.itemName,
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalQuantityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.totalQuantity,
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please enter a quantity';
                        if (int.tryParse(v) == null)
                          return 'Please enter a valid number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
