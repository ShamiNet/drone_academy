// lib/screens/edit_inventory_item_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EditInventoryItemScreen extends StatefulWidget {
  final DocumentSnapshot? item;
  const EditInventoryItemScreen({super.key, this.item});

  @override
  State<EditInventoryItemScreen> createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
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
      final data = widget.item!.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _totalQuantityController.text = data['totalQuantity'].toString();
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
        final data = widget.item!.data() as Map<String, dynamic>;
        final oldTotal = data['totalQuantity'] as int;
        final oldAvailable = data['availableQuantity'] as int;

        // حساب الفارق وإضافته للكمية المتاحة
        final diff = totalQuantity - oldTotal;
        final newAvailable = oldAvailable + diff;

        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(widget.item!.id)
            .update({
              'name': _nameController.text,
              'totalQuantity': totalQuantity,
              'availableQuantity': newAvailable < 0
                  ? 0
                  : newAvailable, // التأكد أن المتاح لا يقل عن صفر
            });
      } else {
        // عند الإضافة، الكمية المتاحة تساوي الكمية الإجمالية
        await FirebaseFirestore.instance.collection('inventory').add({
          'name': _nameController.text,
          'totalQuantity': totalQuantity,
          'availableQuantity': totalQuantity, // الاثنان متساويان عند الإنشاء
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Error saving inventory item: $e");
      // يمكنك إضافة SnackBar لإظهار الخطأ
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
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.itemName),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalQuantityController,
                      decoration: InputDecoration(
                        labelText: l10n.totalQuantity,
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
