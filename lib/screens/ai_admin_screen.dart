import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AiAdminScreen extends StatefulWidget {
  const AiAdminScreen({super.key});

  @override
  State<AiAdminScreen> createState() => _AiAdminScreenState();
}

class _AiAdminScreenState extends State<AiAdminScreen> {
  final _questionController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _includeUsers = true;
  bool _includeTrainings = true;
  bool _includeResults = true;
  bool _includeNotes = true;
  bool _includeEquipment = false;
  bool _includeCompetitions = false;
  bool _includeSchedule = false;
  bool _includeAppReleaseLog = false;
  bool _includeAppControlPanel = false;

  bool _isLoading = false;
  String? _answer;
  String? _error;
  String _mode = 'general';
  int _limit = 50; // ⚡ حد افتراضي للبيانات المجلوبة
  bool _isCached = false; // ⚡ لعرض إشعار عند استخدام الذاكرة المؤقتة
  bool _canUseAI =
      false; // فحص البريد الإلكتروني للسماح باستخدام الذكاء الاصطناعي

  @override
  void initState() {
    super.initState();
    _checkAIAccess();
  }

  // فحص ما إذا كان المستخدم له صلاحية استخدام الذكاء الاصطناعي
  void _checkAIAccess() {
    final user = ApiService.currentUser;
    final hasAccess = user?['email'] == 'kloklop8@gmail.com';
    setState(() {
      _canUseAI = hasAccess;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _sendQuery() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      showCustomSnackBar(context, 'الرجاء كتابة السؤال أو الطلب.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _answer = null;
      _isCached = false;
    });

    final scope = {
      'users': _includeUsers,
      'trainings': _includeTrainings,
      'results': _includeResults,
      'dailyNotes': _includeNotes,
      'equipment': _includeEquipment,
      'competitions': _includeCompetitions,
      'schedule': _includeSchedule,
      'appReleaseLog': _includeAppReleaseLog,
      'appControlPanel': _includeAppControlPanel,
    };

    final response = await _apiService.aiAdminQuery(
      question: question,
      scope: scope,
      mode: _mode,
      limit: _limit, // ⚡ تمرير الحد للـ API
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response['success'] == true) {
        _answer = response['answer']?.toString().trim();
        _isCached =
            response['cached'] == true; // ⚡ كشف إذا كانت من الذاكرة المؤقتة
      } else {
        _error = response['error']?.toString() ?? 'حدث خطأ غير معروف.';
      }
    });
  }

  /// نسخ النتيجة إلى الحافظة
  void _copyToClipboard() {
    if (_answer != null) {
      Clipboard.setData(ClipboardData(text: _answer!));
      showCustomSnackBar(context, '✅ تم نسخ النتيجة بنجاح');
    }
  }

  /// مشاركة النتيجة
  void _shareResult() {
    if (_answer != null) {
      final question = _questionController.text.trim();
      final shareText =
          '''
السؤال: $question

الإجابة:
$_answer

___________
تم إنشاؤها بواسطة مساعد الذكاء الاصطناعي - Drone Academy
''';
      Share.share(shareText, subject: 'نتيجة استعلام الذكاء الاصطناعي');
    }
  }

  Widget _buildScopeSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد الذكاء الاصطناعي')),
      body: !_canUseAI
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ميزة الذكاء الاصطناعي غير متاحة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'عذراً، هذه الميزة متاحة فقط للحسابات المصرح لها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'اكتب طلبك وسيقوم النظام بتحليل البيانات المطلوبة والرد عليك.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _questionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'السؤال أو الطلب',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(
                    labelText: 'نوع الطلب',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('طلب عام')),
                    DropdownMenuItem(value: 'summary', child: Text('ملخصات')),
                    DropdownMenuItem(value: 'qa', child: Text('سؤال وجواب')),
                    DropdownMenuItem(
                      value: 'compare',
                      child: Text('تقارير مقارنة'),
                    ),
                    DropdownMenuItem(
                      value: 'recommend',
                      child: Text('توصيات تدريب'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'نطاق البيانات المسموح بها:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildScopeSwitch(
                  label: 'المستخدمون',
                  value: _includeUsers,
                  onChanged: (v) => setState(() => _includeUsers = v),
                ),
                _buildScopeSwitch(
                  label: 'التدريبات',
                  value: _includeTrainings,
                  onChanged: (v) => setState(() => _includeTrainings = v),
                ),
                _buildScopeSwitch(
                  label: 'النتائج',
                  value: _includeResults,
                  onChanged: (v) => setState(() => _includeResults = v),
                ),
                _buildScopeSwitch(
                  label: 'الملاحظات اليومية',
                  value: _includeNotes,
                  onChanged: (v) => setState(() => _includeNotes = v),
                ),
                _buildScopeSwitch(
                  label: 'المعدات والمخزون',
                  value: _includeEquipment,
                  onChanged: (v) => setState(() => _includeEquipment = v),
                ),
                _buildScopeSwitch(
                  label: 'المسابقات',
                  value: _includeCompetitions,
                  onChanged: (v) => setState(() => _includeCompetitions = v),
                ),
                _buildScopeSwitch(
                  label: 'الجدول',
                  value: _includeSchedule,
                  onChanged: (v) => setState(() => _includeSchedule = v),
                ),
                _buildScopeSwitch(
                  label: 'سجل إصدار التطبيق',
                  value: _includeAppReleaseLog,
                  onChanged: (v) => setState(() => _includeAppReleaseLog = v),
                ),
                _buildScopeSwitch(
                  label: 'لوحة تحكم التطبيق',
                  value: _includeAppControlPanel,
                  onChanged: (v) => setState(() => _includeAppControlPanel = v),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // ⚡ إضافة تحكم في عدد السجلات المجلوبة
                const Text(
                  'حد البيانات (توفير الحصص):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _limit.toDouble(),
                        min: 10,
                        max: 200,
                        divisions: 19,
                        label: '$_limit سجل',
                        onChanged: (value) {
                          setState(() => _limit = value.toInt());
                        },
                      ),
                    ),
                    Text('$_limit', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const Text(
                  'كلما قلّ العدد، قلّ استهلاك حصص Firebase',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendQuery,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_isLoading ? 'جاري التحليل...' : 'إرسال'),
                ),
                const SizedBox(height: 8),
                // ⚡ زر لمسح الذاكرة المؤقتة
                TextButton.icon(
                  onPressed: () {
                    _apiService.clearAllCache();
                    showCustomSnackBar(
                      context,
                      '✅ تم مسح الذاكرة المؤقتة بنجاح',
                    );
                  },
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('مسح الذاكرة المؤقتة (توفير المساحة)'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                // ⚡ إشعار عند استخدام البيانات من الذاكرة المؤقتة
                if (_isCached)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cached, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه النتيجة من الذاكرة المؤقتة (لم يتم استهلاك حصص)',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_answer != null)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // رأس البطاقة مع أزرار الإجراءات
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Colors.green.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'الإجابة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              // زر النسخ
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                tooltip: 'نسخ النتيجة',
                                color: Colors.green.shade700,
                                onPressed: _copyToClipboard,
                              ),
                              // زر المشاركة
                              IconButton(
                                icon: const Icon(Icons.share, size: 20),
                                tooltip: 'مشاركة النتيجة',
                                color: Colors.green.shade700,
                                onPressed: _shareResult,
                              ),
                            ],
                          ),
                        ),
                        // محتوى النتيجة (قابل للتحديد والنسخ)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SelectableText(
                            _answer!,
                            style: const TextStyle(height: 1.6, fontSize: 15),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
