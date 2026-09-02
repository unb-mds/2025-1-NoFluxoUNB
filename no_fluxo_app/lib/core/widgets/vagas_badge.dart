import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Badge de vagas com cor semântica: verde quando há vaga sobrando,
/// vermelho quando zerou, cinza quando o dado é desconhecido.
class VagasBadge extends StatelessWidget {
  /// `vagas_sobrando` da turma (null = dado indisponível).
  final int? vagasSobrando;

  const VagasBadge({super.key, required this.vagasSobrando});

  /// Cor de fundo semântica do badge (exposta para teste).
  static Color corDe(int? vagasSobrando) {
    if (vagasSobrando == null) return AppColors.secondary;
    // Mesmos tons dos status do fluxograma: #1f7a43 / #991b1b.
    return vagasSobrando > 0
        ? AppColors.materiaCompleted
        : AppColors.materiaFailed;
  }

  /// Texto do badge (exposto para teste).
  static String textoDe(int? vagasSobrando) {
    if (vagasSobrando == null) return 'Vagas ?';
    if (vagasSobrando <= 0) return 'Sem vagas';
    return vagasSobrando == 1 ? '1 vaga' : '$vagasSobrando vagas';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corDe(vagasSobrando),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        textoDe(vagasSobrando),
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
