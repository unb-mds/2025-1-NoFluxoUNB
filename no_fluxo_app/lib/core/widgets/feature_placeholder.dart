import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder padronizado para telas ainda não implementadas.
///
/// Cada feature substitui isso pela tela real; o contrato é só o [titulo] no
/// AppBar e o corpo "em construção".
class FeaturePlaceholder extends StatelessWidget {
  final String titulo;
  final IconData icone;

  const FeaturePlaceholder({
    super.key,
    required this.titulo,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icone, size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'em construção',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
