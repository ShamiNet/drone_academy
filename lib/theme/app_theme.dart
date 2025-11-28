import 'package:flutter/material.dart';

// ألوان العلامة البصرية
const Color kSeedBlue = Color(0xFF0D47A1); // أزرق داكن (علامة)
const Color kAccentAmber = Color(0xFFFFA000); // برتقالي مميز (مساند)
const Color kLightBg = Color(0xFFF6F7FB); // خلفية فاتحة ناعمة
const Color kDarkBg = Color(0xFF0F1116); // خلفية داكنة أنيقة

class AppTheme {
  // بناء مخطط الألوان من Seed (Material 3)
  static ColorScheme _lightColorScheme() =>
      ColorScheme.fromSeed(
        seedColor: kSeedBlue,
        brightness: Brightness.light,
      ).copyWith(
        secondary: kAccentAmber,
        surface: Colors.white,
        background: kLightBg,
      );

  static ColorScheme _darkColorScheme() =>
      ColorScheme.fromSeed(
        seedColor: kSeedBlue,
        brightness: Brightness.dark,
      ).copyWith(
        secondary: kAccentAmber,
        surface: const Color(0xFF151821),
        background: kDarkBg,
      );

  // قاعدات مشتركة بين الثيمين
  static ThemeData _baseTheme(ColorScheme scheme, {required bool isDark}) {
    // تطبيق Cairo على جميع النصوص وضمان التباين الصحيح
    final textTheme = Typography.englishLike2021.apply(
      fontFamily: 'Cairo',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    const radius = 14.0;
    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // AppBar أكثر حداثة
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.primary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.primary),
      ),

      // الأزرار
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: roundedShape,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: roundedShape,
          side: BorderSide(color: scheme.primary.withOpacity(0.5)),
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          shape: roundedShape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      iconTheme: IconThemeData(color: scheme.primary),

      // حقول الإدخال
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2230) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),

      // البطاقات
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0.8,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        shadowColor: scheme.shadow.withOpacity(0.1),
      ),

      // FAB مع شكل ممتد أنيق
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // تبويبات
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 3),
        ),
        labelStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.titleMedium,
      ),

      // شرائح وشيبس
      chipTheme: ChipThemeData(
        color: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.secondaryContainer;
          }
          return (isDark ? const Color(0xFF1C2230) : Colors.white);
        }),
        labelStyle: textTheme.bodyMedium!,
        side: BorderSide(color: scheme.outlineVariant),
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        iconTheme: IconThemeData(color: scheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // سنackbar موحد
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1E2633)
            : scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: scheme.secondary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // حوارات
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 32,
      ),

      // List Tiles مع ألوان متباينة
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
        tileColor: scheme.surface,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withOpacity(0.7),
        ),
      ),

      // انتقالات سلسة عبر المنصات
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  // الثيم الفاتح
  static final ThemeData lightTheme = _baseTheme(
    _lightColorScheme(),
    isDark: false,
  );

  // الثيم الداكن
  static final ThemeData darkTheme = _baseTheme(
    _darkColorScheme(),
    isDark: true,
  );
}
