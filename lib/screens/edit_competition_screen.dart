import 'package:animate_do/animate_do.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class EditCompetitionScreen extends StatefulWidget {
  final Map<String, dynamic>? competition; // Map
  const EditCompetitionScreen({super.key, this.competition});

  @override
  State<EditCompetitionScreen> createState() => _EditCompetitionScreenState();
}

class _EditCompetitionScreenState extends State<EditCompetitionScreen> {
  final ApiService _apiService = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;
  bool get _isEditing => widget.competition != null;
  bool _isSaving = false;

  // ألوان التصميم
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.competition!['title'];
      _descriptionController.text = widget.competition!['description'];
      _isActive = widget.competition!['isActive'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCompetition() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'metric': 'time', // افتراضي
        'isActive': _isActive,
      };

      if (_isEditing) {
        await _apiService.updateCompetition(widget.competition!['id'], data);
      } else {
        await _apiService.addCompetition(data);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          _isEditing ? l10n.editCompetition : l10n.addNewCompetition,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSaving
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الهيدر الجمالي
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accentColor, _bgColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.emoji_events,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isEditing
                                  ? "تعديل تفاصيل المسابقة"
                                  : "إنشاء مسابقة جديدة",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "أدخل البيانات المطلوبة لإطلاق التحدي",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 2. الحقول
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildInputCard(
                        label: l10n.enterTitle,
                        icon: Icons.title,
                        child: TextFormField(
                          controller: _titleController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: l10n.enterTitle,
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildInputCard(
                        label: l10n.enterDescription,
                        icon: Icons.description_outlined,
                        child: TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "وصف المسابقة وقواعدها...",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. حالة المسابقة
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isActive
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            l10n.activeCompetition,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? "المسابقة متاحة للمتدربين"
                                : "المسابقة مغلقة حالياً",
                            style: TextStyle(
                              color: _isActive ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          value: _isActive,
                          activeColor: Colors.green,
                          secondary: Icon(
                            _isActive ? Icons.check_circle : Icons.cancel,
                            color: _isActive ? Colors.green : Colors.grey,
                          ),
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 4. زر الحفظ
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _saveCompetition,
                          icon: const Icon(
                            Icons.save_outlined,
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 10,
                            shadowColor: _primaryColor.withOpacity(0.4),
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
    required String label,
    required IconData icon,
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
          Padding(padding: const EdgeInsets.only(left: 26.0), child: child),
        ],
      ),
    );
  }
}
