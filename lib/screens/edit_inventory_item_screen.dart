import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class EditInventoryItemScreen extends StatefulWidget {
  final Map<String, dynamic>? item; // Map
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final totalQuantity = int.tryParse(_totalQuantityController.text) ?? 0;

    try {
      if (_isEditing) {
        final oldTotal = widget.item!['totalQuantity'] as int;
        final oldAvailable = widget.item!['availableQuantity'] as int;
        final diff = totalQuantity - oldTotal;
        final newAvailable = oldAvailable + diff;

        await _apiService.updateInventoryItem(widget.item!['id'], {
          'name': _nameController.text,
          'totalQuantity': totalQuantity,
          'availableQuantity': newAvailable < 0 ? 0 : newAvailable,
        });
      } else {
        await _apiService.addInventoryItem({
          'name': _nameController.text,
          'totalQuantity': totalQuantity,
          'availableQuantity': totalQuantity,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.editInventoryItem : l10n.addInventoryItem,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveItem),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.itemName),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalQuantityController,
                      decoration: InputDecoration(
                        labelText: l10n.totalQuantity,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
