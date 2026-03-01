class AiQueryHistory {
  final String id;
  final String question;
  final String answer;
  final String mode;
  final Map<String, bool> scope;
  final DateTime timestamp;
  final String userName;
  final int dataLimit;

  AiQueryHistory({
    required this.id,
    required this.question,
    required this.answer,
    required this.mode,
    required this.scope,
    required this.timestamp,
    required this.userName,
    this.dataLimit = 50,
  });

  // تحويل إلى JSON للحفظ في SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'mode': mode,
      'scope': scope,
      'timestamp': timestamp.toIso8601String(),
      'userName': userName,
      'dataLimit': dataLimit,
    };
  }

  // إنشاء من JSON
  factory AiQueryHistory.fromJson(Map<String, dynamic> json) {
    return AiQueryHistory(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      mode: json['mode'] ?? 'general',
      scope: Map<String, bool>.from(json['scope'] ?? {}),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      userName: json['userName'] ?? 'Unknown',
      dataLimit: json['dataLimit'] ?? 50,
    );
  }

  // نسخة مع تعديلات
  AiQueryHistory copyWith({
    String? id,
    String? question,
    String? answer,
    String? mode,
    Map<String, bool>? scope,
    DateTime? timestamp,
    String? userName,
    int? dataLimit,
  }) {
    return AiQueryHistory(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      mode: mode ?? this.mode,
      scope: scope ?? this.scope,
      timestamp: timestamp ?? this.timestamp,
      userName: userName ?? this.userName,
      dataLimit: dataLimit ?? this.dataLimit,
    );
  }

  // وصف نطاق البيانات بالعربية
  String getScopeDescription() {
    final List<String> activeScopes = [];
    if (scope['users'] == true) activeScopes.add('المستخدمون');
    if (scope['trainings'] == true) activeScopes.add('التدريبات');
    if (scope['results'] == true) activeScopes.add('النتائج');
    if (scope['dailyNotes'] == true) activeScopes.add('الملاحظات');
    if (scope['equipment'] == true) activeScopes.add('المعدات');
    if (scope['competitions'] == true) activeScopes.add('المسابقات');
    if (scope['schedule'] == true) activeScopes.add('الجدول');
    if (scope['appReleaseLog'] == true) activeScopes.add('سجل الإصدار');
    if (scope['appControlPanel'] == true) activeScopes.add('لوحة تحكم التطبيق');

    return activeScopes.isEmpty ? 'لا يوجد' : activeScopes.join('، ');
  }

  // ترجمة نوع الاستعلام
  String getModeLabel() {
    switch (mode) {
      case 'general':
        return 'طلب عام';
      case 'summary':
        return 'ملخصات';
      case 'qa':
        return 'سؤال وجواب';
      case 'compare':
        return 'تقارير مقارنة';
      case 'recommend':
        return 'توصيات تدريب';
      default:
        return mode;
    }
  }
}
