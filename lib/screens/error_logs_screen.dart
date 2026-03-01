import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للنسخ
import 'package:intl/intl.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  late Future<List<dynamic>> _errorsFuture;

  @override
  void initState() {
    super.initState();
    final ApiService apiService = ApiService();
    _errorsFuture = apiService.fetchSystemErrors();
  }

  Future<void> _onRefresh() async {
    final ApiService apiService = ApiService();
    setState(() {
      _errorsFuture = apiService.fetchSystemErrors();
    });
  }

  // --- دالة المساعدة لتحليل الخطأ وتبسيطه ---
  String _getSimpleExplanation(String error) {
    final e = error.toLowerCase();

    if (e.contains('socketexception') ||
        e.contains('connection refused') ||
        e.contains('clientexception')) {
      return "🌐 مشكلة في الاتصال: التطبيق لا يستطيع الوصول للسيرفر. تأكد من الإنترنت أو تشغيل السيرفر.";
    }
    if (e.contains('null check operator') || e.contains('null value')) {
      return "⚠️ قيمة فارغة: الكود يحاول استخدام متغير قيمته (Null) في مكان غير مسموح.";
    }
    if (e.contains('login_fail') ||
        e.contains('status: 400') ||
        e.contains('status: 403')) {
      return "🔐 فشل دخول: بيانات الدخول خاطئة أو الحساب محظور.";
    }
    if (e.contains('status: 404')) {
      return "❌ غير موجود: الرابط المطلوب غير موجود في السيرفر (Endpoint Not Found).";
    }
    if (e.contains('status: 500')) {
      return "🔥 خطأ سيرفر داخلي: حدثت مشكلة في كود السيرفر (Backend) نفسه.";
    }
    if (e.contains('formatexception')) {
      return "📄 خطأ في التنسيق: البيانات القادمة (JSON) ليست بالشكل المتوقع.";
    }
    if (e.contains('timeout')) {
      return "⏳ انتهى الوقت: السيرفر استغرق وقتاً طويلاً جداً للرد.";
    }

    return "❓ خطأ برمجي عام: يفضل نسخ الكود وتحليله.";
  }

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "سجل الأخطاء البرمجية",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            tooltip: "تجربة خطأ وهمي",
            onPressed: () {
              throw Exception(
                "هذا اختبار للنظام! خطأ تجريبي تم توليده يدوياً.",
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<dynamic>>(
          future: _errorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final errors = snapshot.data ?? [];

            if (errors.isEmpty) {
              return const Center(
                child: Text(
                  "النظام سليم! لا توجد أخطاء مسجلة.",
                  style: TextStyle(color: Colors.green),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: errors.length,
              itemBuilder: (context, index) {
                final errorLog = errors[index];
                // الحصول على المعرف للحذف (مهم جداً للـ Dismissible)
                final String logId = errorLog['id'] ?? UniqueKey().toString();

                DateTime date;
                try {
                  if (errorLog['timestamp'] != null) {
                    date = DateTime.parse(errorLog['timestamp'].toString());
                  } else {
                    date = DateTime.now();
                  }
                } catch (e) {
                  date = DateTime.now();
                }

                final String errorMsg = errorLog['error'] ?? 'Unknown Error';
                final String explanation = _getSimpleExplanation(errorMsg);

                // 🟢 التغيير هنا: استخدام Dismissible للسحب للحذف
                return Dismissible(
                  key: Key(logId), // مفتاح فريد للعنصر
                  direction: DismissDirection
                      .endToStart, // السحب من اليمين لليسار (أو العكس حسب اللغة)
                  // خلفية الحذف (لون أحمر وأيقونة سلة المهملات)
                  background: Container(
                    margin: const EdgeInsets.only(
                      bottom: 16,
                    ), // نفس مارجن الكارد
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment:
                        AlignmentDirectional.centerEnd, // محاذاة الأيقونة للطرف
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "حذف",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.delete, color: Colors.white),
                      ],
                    ),
                  ),

                  // ماذا يحدث عند السحب
                  onDismissed: (direction) {
                    apiService.deleteErrorLog(logId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم حذف السجل من السيرفر"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },

                  // العنصر الأساسي (الكارد)
                  child: Card(
                    color: const Color(0xFF1E2230),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: ExpansionTile(
                      collapsedIconColor: Colors.grey,
                      iconColor: Colors.orange,
                      leading: const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        errorMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "${DateFormat('yyyy/MM/dd HH:mm').format(date)} • ${errorLog['userName'] ?? 'User'}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    explanation,
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.black38,
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "التفاصيل البرمجية (Stack Trace):",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                errorLog['stackTrace'] ?? 'No stack trace',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text("نسخ للذكاء الاصطناعي"),
                                onPressed: () {
                                  final textToCopy =
                                      "Error Context: $explanation\n\nFull Error: ${errorLog['error']}\n\nStack Trace:\n${errorLog['stackTrace']}";
                                  Clipboard.setData(
                                    ClipboardData(text: textToCopy),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "تم النسخ! ألصقه في الشات.",
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              // 🟢 تم حذف زر الحذف القديم من هنا
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
