import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/release.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

/// Chave de "release visto" no SharedPreferences, por usuário.
String chaveReleaseVisto(int idUser) => 'release_visto_$idUser';

/// Mostra o dialog de novidades UMA vez por usuário+release.
///
/// Chamado no primeiro build da aba Perfil para usuário logado. Persiste
/// [kReleaseId] em `release_visto_<idUser>` — um release novo (string nova)
/// reabre o dialog. Falhas (prefs indisponível, contexto desmontado) são
/// silenciosas: na dúvida, não mostra.
Future<void> mostrarNovidadesSeNecessario(
  BuildContext context,
  WidgetRef ref,
) async {
  final estado = ref.read(authProvider).valueOrNull;
  final idUser = estado?.user?.idUser;
  if (idUser == null) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final chave = chaveReleaseVisto(idUser);
    if (prefs.getString(chave) == kReleaseId) return;
    await prefs.setString(chave, kReleaseId);
  } catch (e) {
    debugPrint('Novidades: prefs indisponível, não mostrando: $e');
    return;
  }

  if (!context.mounted) return;
  await mostrarNovidades(context);
}

/// Abre o dialog de novidades (também usado pelo item "Novidades" do Perfil).
Future<void> mostrarNovidades(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const NovidadesDialog(),
  );
}

/// Dialog "Novidades no NoFluxo" com a lista de [kNovidades] do release.
class NovidadesDialog extends StatelessWidget {
  const NovidadesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(kNovidadesTitulo, style: tema.titleLarge)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final novidade in kNovidades)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        novidade,
                        style: tema.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
