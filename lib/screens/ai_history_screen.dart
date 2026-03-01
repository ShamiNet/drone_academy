import 'package:drone_academy/models/ai_query_history.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({super.key});

  @override
  State<AiHistoryScreen> createState() => _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _accentColor = const Color(0xFFFF9800);

  List<AiQueryHistory> _allHistory = [];
  List<AiQueryHistory> _filteredHistory = [];
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _apiService.getAiQueryHistory();
      final stats = await _apiService.getAiHistoryStats();
      setState(() {
        _allHistory = history;
        _filteredHistory = history;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showCustomSnackBar(context, 'خطأ في تحميل السجل: $e');
      }
    }
  }

  void _onSearchChanged(String keyword) {
    if (keyword.isEmpty) {
      setState(() => _filteredHistory = _allHistory);
    } else {
      setState(() {
        _filteredHistory = _allHistory.where((query) {
          final lowerKeyword = keyword.toLowerCase();
          return query.question.toLowerCase().contains(lowerKeyword) ||
              query.answer.toLowerCase().contains(lowerKeyword) ||
              query.getModeLabel().toLowerCase().contains(lowerKeyword);
        }).toList();
      });
    }
  }

  Future<void> _deleteQuery(String queryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد حذف هذا الاستعلام من السجل؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.deleteAiQueryFromHistory(queryId);
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, '✅ تم الحذف بنجاح');
          _loadHistory();
        }
      } else {
        if (mounted) {
          showCustomSnackBar(context, '❌ فشل الحذف');
        }
      }
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('⚠️ تحذير', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد مسح جميع السجلات؟\nهذا الإجراء لا يمكن التراجع عنه.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.clearAiQueryHistory();
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, '✅ تم مسح جميع السجلات');
          _loadHistory();
        }
      }
    }
  }

  void _showQueryDetails(AiQueryHistory query) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // مقبض السحب
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // العنوان مع أزرار الإجراءات
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تفاصيل الاستعلام',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.white70,
                      ),
                      tooltip: 'نسخ النتيجة',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: query.answer));
                        showCustomSnackBar(context, '✅ تم النسخ');
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.share,
                        size: 20,
                        color: Colors.white70,
                      ),
                      tooltip: 'مشاركة النتيجة',
                      onPressed: () {
                        final shareText =
                            '''
السؤال: ${query.question}

الإجابة:
${query.answer}

النوع: ${query.getModeLabel()}
التاريخ: ${DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(query.timestamp)}
النطاق: ${query.getScopeDescription()}
___________
سجل الذكاء الاصطناعي - Drone Academy
''';
                        Share.share(
                          shareText,
                          subject: 'استعلام الذكاء الاصطناعي',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'حذف',
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteQuery(query.id);
                      },
                    ),
                  ],
                ),
                const Divider(height: 30, color: Colors.white24),

                // التاريخ والوقت
                _buildInfoRow(
                  icon: Icons.access_time,
                  label: 'التاريخ والوقت',
                  value: DateFormat(
                    'yyyy/MM/dd - hh:mm a',
                    'ar',
                  ).format(query.timestamp),
                ),
                const SizedBox(height: 12),

                // اسم المستخدم
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'المستخدم',
                  value: query.userName,
                ),
                const SizedBox(height: 12),

                // نوع الاستعلام
                _buildInfoRow(
                  icon: Icons.category,
                  label: 'نوع الطلب',
                  value: query.getModeLabel(),
                ),
                const SizedBox(height: 12),

                // حد البيانات
                _buildInfoRow(
                  icon: Icons.data_usage,
                  label: 'حد البيانات',
                  value: '${query.dataLimit} سجل',
                ),
                const SizedBox(height: 12),

                // نطاق البيانات
                _buildInfoRow(
                  icon: Icons.storage,
                  label: 'نطاق البيانات',
                  value: query.getScopeDescription(),
                ),
                const Divider(height: 30, color: Colors.white24),

                // السؤال
                const Text(
                  'السؤال:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SelectableText(
                    query.question,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // الإجابة
                const Text(
                  'الإجابة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SelectableText(
                    query.answer,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        title: const Text(
          'سجل استعلامات الذكاء الاصطناعي',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_allHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'مسح جميع السجلات',
              onPressed: _clearAllHistory,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            color: _cardColor,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث في السجل...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                filled: true,
                fillColor: _bgColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // إحصائيات السجل
          if (_stats != null && _stats!['total'] > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.history,
                    label: 'إجمالي الاستعلامات',
                    value: '${_stats!['total']}',
                  ),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _buildStatItem(
                    icon: Icons.offline_bolt,
                    label: 'متاح بدون إنترنت',
                    value: '✓',
                    color: Colors.green,
                  ),
                ],
              ),
            ),

          // قائمة السجلات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isEmpty
                              ? Icons.history_edu
                              : Icons.search_off,
                          size: 80,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'لا توجد استعلامات محفوظة بعد'
                              : 'لا توجد نتائج للبحث',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        if (_searchController.text.isEmpty)
                          Text(
                            'قم بإجراء استعلام من صفحة الذكاء الاصطناعي',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final query = _filteredHistory[index];
                      return _buildQueryCard(query);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.purple, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.purple,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildQueryCard(AiQueryHistory query) {
    return Card(
      color: _cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showQueryDetails(query),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس البطاقة: التاريخ ونوع الطلب
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getModeColor(query.mode).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getModeColor(query.mode).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      query.getModeLabel(),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getModeColor(query.mode),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy').format(query.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 10),

              // السؤال (مختصر)
              Text(
                query.question.length > 80
                    ? '${query.question.substring(0, 80)}...'
                    : query.question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // الإجابة (مختصرة)
              Text(
                query.answer.length > 120
                    ? '${query.answer.substring(0, 120)}...'
                    : query.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // الإجراءات السفلية
              Row(
                children: [
                  Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      query.getScopeDescription(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Colors.white70,
                    ),
                    tooltip: 'نسخ الإجابة',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: query.answer));
                      showCustomSnackBar(context, '✅ تم النسخ');
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      size: 18,
                      color: Colors.white70,
                    ),
                    tooltip: 'مشاركة',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final shareText =
                          '''
السؤال: ${query.question}

الإجابة:
${query.answer}
___________
Drone Academy - AI
''';
                      Share.share(shareText);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red,
                    tooltip: 'حذف',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteQuery(query.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'summary':
        return Colors.blue;
      case 'qa':
        return Colors.green;
      case 'compare':
        return Colors.orange;
      case 'recommend':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
