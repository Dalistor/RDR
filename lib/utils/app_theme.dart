import 'package:flutter/material.dart';

import '../models/section_kind.dart';

/// Tema claro único do app e as cores das três seções da reunião.
///
/// As cores são as mesmas usadas pelo wol.jw.org nos títulos das seções.
/// Nenhum widget deve repetir esses literais: use [AppTheme.sectionColor]
/// para obter a cor a partir do [SectionKind].
abstract final class AppTheme {
  /// Tesouros da Palavra de Deus — teal (`du-color--teal-700`).
  static const Color treasuresColor = Color(0xFF26697C);

  /// Faça Seu Melhor no Ministério — dourado (`du-color--gold-700`).
  static const Color ministryColor = Color(0xFF9B6E1A);

  /// Nossa Vida Cristã — vinho (`du-color--maroon-600`).
  static const Color christianLifeColor = Color(0xFFA33B2A);

  /// Cor da seção, usada em cabeçalhos, ícones e no print do relatório.
  static Color sectionColor(SectionKind kind) => switch (kind) {
    SectionKind.treasures => treasuresColor,
    SectionKind.ministry => ministryColor,
    SectionKind.christianLife => christianLifeColor,
  };

  /// Tema claro. O app não tem tema escuro: a interface e o print do
  /// relatório são sempre de fundo branco.
  static ThemeData get light {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: treasuresColor,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: treasuresColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
