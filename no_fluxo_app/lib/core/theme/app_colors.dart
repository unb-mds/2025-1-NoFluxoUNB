import 'package:flutter/material.dart';

/// Paleta do NoFluxo mobile — dark-only "premium".
///
/// Cores base espelham o design do site; as cores por status de matéria são
/// as usadas nos cards do fluxograma.
class AppColors {
  AppColors._();

  // ── Base (dark) ────────────────────────────────────────────────────────────
  /// Fundo do app.
  static const Color background = Color(0xFF060608);

  /// Superfícies elevadas (cards, sheets, dialogs).
  static const Color surface = Color(0xFF101013);

  /// Roxo primário da marca.
  static const Color primary = Color(0xFF8B44F5);

  /// Superfície secundária (chips, inputs, botões neutros).
  static const Color secondary = Color(0xFF1C1C20);

  /// Texto principal.
  static const Color foreground = Color(0xFFF4F4F6);

  /// Texto secundário / apagado.
  static const Color mutedForeground = Color(0xFF8A8A93);

  /// Bordas e divisores.
  static const Color border = Color(0xFF26262B);

  /// Lilás de destaque das features de IA.
  static const Color accent = Color(0xFFC39DFA);

  /// Ações destrutivas / erro.
  static const Color destructive = Color(0xFFDC2626);

  // ── Status de matéria no fluxograma ────────────────────────────────────────
  /// Concluída (APR / CUMP / DISP).
  static const Color materiaCompleted = Color(0xFF1F7A43);

  /// Em curso (MATR).
  static const Color materiaInProgress = Color(0xFF6B2FCF);

  /// Disponível para cursar (pré-requisitos cumpridos).
  static const Color materiaAvailable = Color(0xFFA8671A);

  /// Reprovada (REP).
  static const Color materiaFailed = Color(0xFF991B1B);

  /// Bloqueada / não iniciada.
  static const Color materiaLocked = Color(0xFF161625);

  // ── Destaques ──────────────────────────────────────────────────────────────
  /// Matéria cumprida por equivalência.
  static const Color destaqueEquivalencia = Color(0xFF7F9CF5);

  /// Módulo livre / eletiva fora da matriz.
  static const Color destaqueModuloLivre = Color(0xFF4FD1C5);

  /// Optativa.
  static const Color destaqueOptativa = Color(0xFFF6AD55);

  // A cor por status de matéria vive em StatusMateriaX.cor
  // (features/fluxograma/domain/status_resolver.dart) — fonte única; um
  // mapeamento paralelo aqui já divergiu uma vez e foi removido.
}
