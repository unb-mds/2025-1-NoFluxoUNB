import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema dark-only do NoFluxo mobile (Material 3).
///
/// Tipografia: Inter no corpo, Poppins (semibold, tracking apertado) nos
/// títulos e JetBrains Mono para códigos de matéria ([codigoMateriaStyle]).
class AppTheme {
  AppTheme._();

  /// Raio padrão de cards e inputs.
  static const double radius = 12;

  /// Estilo mono para códigos de matéria (ex.: "FGA0158").
  static TextStyle codigoMateriaStyle({
    double fontSize = 13,
    Color color = AppColors.mutedForeground,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: 0.2,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.foreground,
      tertiary: AppColors.accent,
      onTertiary: Color(0xFF1A0B2E),
      surface: AppColors.surface,
      onSurface: AppColors.foreground,
      onSurfaceVariant: AppColors.mutedForeground,
      surfaceContainerHighest: AppColors.secondary,
      surfaceContainerLow: AppColors.surface,
      error: AppColors.destructive,
      onError: Colors.white,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    // Corpo em Inter; títulos em Poppins semibold com tracking apertado.
    final corpo = GoogleFonts.interTextTheme(base.textTheme);
    TextStyle? titulo(TextStyle? estilo, double tamanho) => estilo == null
        ? null
        : GoogleFonts.poppins(
            textStyle: estilo,
            fontSize: tamanho,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: AppColors.foreground,
          );

    final textTheme = corpo.copyWith(
      displayLarge: titulo(corpo.displayLarge, 44),
      displayMedium: titulo(corpo.displayMedium, 36),
      displaySmall: titulo(corpo.displaySmall, 30),
      headlineLarge: titulo(corpo.headlineLarge, 28),
      headlineMedium: titulo(corpo.headlineMedium, 24),
      headlineSmall: titulo(corpo.headlineSmall, 20),
      titleLarge: titulo(corpo.titleLarge, 18),
      titleMedium: titulo(corpo.titleMedium, 16),
      titleSmall: titulo(corpo.titleSmall, 14),
      bodyLarge: corpo.bodyLarge?.copyWith(color: AppColors.foreground),
      bodyMedium: corpo.bodyMedium?.copyWith(color: AppColors.foreground),
      bodySmall: corpo.bodySmall?.copyWith(color: AppColors.mutedForeground),
      labelLarge: corpo.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    RoundedRectangleBorder borda([double r = radius]) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titulo(corpo.titleLarge, 20),
        iconTheme: const IconThemeData(color: AppColors.foreground),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondary,
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.destructive),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: borda(),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.border),
          shape: borda(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: borda(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selecionado = states.contains(WidgetState.selected);
          // Sem letter-spacing e com ellipsis: "Notificações" precisa caber em
          // 1/5 da tela sem quebrar em duas linhas.
          return corpo.labelSmall!.copyWith(
            fontSize: 11,
            letterSpacing: 0,
            height: 1.2,
            overflow: TextOverflow.ellipsis,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
            color: selecionado
                ? AppColors.foreground
                : AppColors.mutedForeground,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.mutedForeground,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: corpo.bodyMedium?.copyWith(
          color: AppColors.foreground,
        ),
        behavior: SnackBarBehavior.floating,
        shape: borda(10),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: borda(14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.secondary,
        side: const BorderSide(color: AppColors.border),
        labelStyle: corpo.labelMedium?.copyWith(color: AppColors.foreground),
        shape: borda(10),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
