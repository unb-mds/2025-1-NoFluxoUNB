import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

/// Bottom sheet "Como obter seu histórico acadêmico" — os 3 passos do
/// HelpModal do site, sem as imagens (texto + link para o SIGAA).
Future<void> mostrarAjudaHistorico(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _AjudaHistoricoSheet(),
  );
}

class _AjudaHistoricoSheet extends StatelessWidget {
  const _AjudaHistoricoSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Como obter seu histórico acadêmico',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _Passo(
              numero: 1,
              titulo: 'Acesse o SIGAA',
              descricao: 'Entre no SIGAA com seu login e senha institucional.',
              trailing: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://sig.unb.br/sigaa/'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Abrir o SIGAA'),
              ),
            ),
            _Passo(
              numero: 2,
              titulo: 'Selecione "Emitir Histórico"',
              descricao:
                  'No menu lateral, clique em Ensino e depois em '
                  'Emitir Histórico.',
            ),
            _Passo(
              numero: 3,
              titulo: 'Faça o upload do PDF para o NoFluxoUNB',
              descricao:
                  'Salve o arquivo PDF gerado e faça o upload nesta tela.',
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final int numero;
  final String titulo;
  final String descricao;
  final Widget? trailing;

  const _Passo({
    required this.numero,
    required this.titulo,
    required this.descricao,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              '$numero',
              style: textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (trailing != null)
                  Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
