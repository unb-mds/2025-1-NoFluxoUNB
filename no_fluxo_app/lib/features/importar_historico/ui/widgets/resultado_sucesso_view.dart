import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/casamento.dart';
import '../../providers/importar_historico_controller.dart';

/// Tela de sucesso — porte de UploadSuccess + os 4 stat cards do
/// ProcessingResults do site.
class ResultadoSucessoView extends StatelessWidget {
  final CasarDisciplinasResultado resultado;
  final bool salvando;
  final VoidCallback onVisualizarFluxograma;
  final VoidCallback onEnviarOutro;

  const ResultadoSucessoView({
    super.key,
    required this.resultado,
    required this.salvando,
    required this.onVisualizarFluxograma,
    required this.onEnviarOutro,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resumo = resultado.resumo;
    final optativas = contarOptativasExibidas(resultado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: AppColors.materiaCompleted,
        ),
        const SizedBox(height: 12),
        Text(
          'Processamento concluído',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Seu histórico foi processado. Revise os dados abaixo antes de '
          'abrir o fluxograma.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StatCard(
              rotulo: 'Total de Obrigatórias',
              valor: resumo.totalObrigatorias,
              icone: Icons.menu_book_outlined,
              cor: AppColors.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              rotulo: 'Concluídas (obrig.)',
              valor: resumo.totalObrigatoriasConcluidas,
              icone: Icons.check_circle_outline,
              cor: AppColors.materiaCompleted,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatCard(
              rotulo: 'Pendentes (obrig.)',
              valor: resumo.totalObrigatoriasPendentes,
              icone: Icons.warning_amber_outlined,
              cor: AppColors.materiaAvailable,
            ),
            const SizedBox(width: 8),
            _StatCard(
              rotulo: 'Optativas',
              valor: optativas,
              icone: Icons.star_outline,
              cor: AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: salvando ? null : onVisualizarFluxograma,
          icon: salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: const Text('Visualizar fluxograma'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: salvando ? null : onEnviarOutro,
          icon: const Icon(Icons.refresh),
          label: const Text('Enviar outro PDF'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String rotulo;
  final int valor;
  final IconData icone;
  final Color cor;

  const _StatCard({
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(height: 6),
            Text(
              '$valor',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rotulo,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
