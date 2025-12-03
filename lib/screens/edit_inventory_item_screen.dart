import 'package:animate_do/animate_do.dart';
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

  // ألوان التصميم
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800); // برتقالي
  final Color _accentColor = const Color(0xFF3F51B5); // أزرق

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
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? l10n.editInventoryItem : l10n.addInventoryItem,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveItem,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. هيدر أيقوني
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: _primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 2. اسم القطعة
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildInputCard(
                        icon: Icons.label_outline,
                        label: l10n.itemName,
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "مثال: مروحة احتياطية",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. الكمية
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildInputCard(
                        icon: Icons.numbers,
                        label: l10n.totalQuantity,
                        child: TextFormField(
                          controller: _totalQuantityController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "0",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // 4. زر الحفظ الكبير
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: _primaryColor.withOpacity(0.4),
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.black,
                          ),
                          label: Text(
                            l10n.save,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ودجت مساعد للحقول
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26.0, bottom: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}
