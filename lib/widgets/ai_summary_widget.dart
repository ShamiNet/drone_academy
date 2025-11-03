// lib/widgets/ai_summary_widget.dart

import 'package:flutter/material.dart';

class AiSummaryWidget extends StatelessWidget {
  final String summary;
  const AiSummaryWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> textSpans = [];
    // 1. تعبير برمجي (RegEx) للعثور على أي نص بين نجمتين **...**
    final regex = RegExp(r'\*\*(.*?)\*\*');

    // 2. استخدام دالة splitMapJoin لفصل النص المطابق عن غير المطابق
    summary.splitMapJoin(
      regex,
      onMatch: (match) {
        // 3. هذا هو النص "المطابق" (الذي كان بين النجمتين)
        textSpans.add(
          TextSpan(
            text: match.group(1), // .group(1) هو النص الذي تم التقاطه
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.secondary, // لون مميز (مثل الأزرق أو البرتقالي)
              fontWeight: FontWeight.bold, // خط عريض
              fontSize: 16, // حجم خط أكبر قليلاً
            ),
          ),
        );
        return ''; // قمنا بمعالجة هذا الجزء
      },
      onNonMatch: (nonMatch) {
        // 4. هذا هو النص "غير المطابق" (العادي)
        textSpans.add(
          TextSpan(
            text: nonMatch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5, // لزيادة التباعد بين الأسطر
              fontSize: 15,
            ),
          ),
        );
        return ''; // قمنا بمعالجة هذا الجزء
      },
    );

    // 5. استخدام RichText لعرض النصوص بالأنماط المختلفة
    return RichText(
      text: TextSpan(children: textSpans),
      textDirection: TextDirection.rtl, // ضمان اتجاه النص
    );
  }
}
