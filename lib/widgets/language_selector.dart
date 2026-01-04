import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/main.dart' show MyAppState;
import 'package:drone_academy/services/language_service.dart';
import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final bool showTitle;
  final bool isCompact;
  final Function(Locale)? onLanguageChanged;

  const LanguageSelector({
    super.key,
    this.showTitle = true,
    this.isCompact = false,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);

    if (isCompact) {
      return _buildCompactSelector(context, currentLocale);
    }

    return _buildFullSelector(context, currentLocale, l10n);
  }

  Widget _buildCompactSelector(BuildContext context, Locale currentLocale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: currentLocale.languageCode,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1E2E),
        icon: const Icon(Icons.language, color: Colors.white70, size: 20),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: LanguageService.supportedLocales.map((locale) {
          return DropdownMenuItem(
            value: locale.languageCode,
            child: Text(
              LanguageService.languageNames[locale.languageCode] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (value) => _changeLanguage(context, value),
      ),
    );
  }

  Widget _buildFullSelector(
    BuildContext context,
    Locale currentLocale,
    AppLocalizations? l10n,
  ) {
    return Card(
      color: const Color(0xFF1E1E2E),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Row(
                children: [
                  const Icon(Icons.language, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    l10n?.selectLanguage ?? 'اختر اللغة',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...LanguageService.supportedLocales.map((locale) {
              final isSelected =
                  currentLocale.languageCode == locale.languageCode;
              return _buildLanguageOption(context, locale, isSelected);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    Locale locale,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: () => _changeLanguage(context, locale.languageCode),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _getLanguageFlag(locale.languageCode),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          LanguageService.languageNames[locale.languageCode] ?? '',
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          LanguageService.getLanguageNameInArabic(locale.languageCode),
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.blue, size: 24)
            : const Icon(
                Icons.circle_outlined,
                color: Colors.white30,
                size: 24,
              ),
      ),
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return '🇸🇦'; // علم السعودية للعربية
      case 'en':
        return '🇬🇧'; // علم بريطانيا للإنجليزية
      case 'ru':
        return '🇷🇺'; // علم روسيا للروسية
      default:
        return '🌐';
    }
  }

  void _changeLanguage(BuildContext context, String? languageCode) async {
    if (languageCode == null) return;

    // حفظ اللغة
    await LanguageService.saveLanguage(languageCode);

    // تغيير اللغة في التطبيق
    final newLocale = Locale(languageCode);

    if (onLanguageChanged != null) {
      onLanguageChanged!(newLocale);
    } else {
      // استخدام الطريقة الافتراضية لتغيير اللغة
      if (context.mounted) {
        // البحث عن MyApp وتحديث اللغة
        final myAppState = context.findAncestorStateOfType<MyAppState>();
        if (myAppState != null) {
          myAppState.setLocale(newLocale);
        }
      }
    }

    // إظهار رسالة تأكيد
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ تم تغيير اللغة إلى ${LanguageService.getLanguageNativeName(languageCode)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
