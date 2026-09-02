import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/curso_model.dart';
import '../../../core/models/materia_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/status_resolver.dart';
import '../../../core/config/rotas.dart';

/// Abre o bottom sheet com os detalhes da matéria tocada no fluxograma.
Future<void> mostrarDetalhesMateria(
  BuildContext context, {
  required MateriaModel materia,
  required CursoModel curso,
  required ResultadoStatus resultado,
  DadosMateria? dadosUsuario,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MateriaDetailsSheet(
      materia: materia,
      curso: curso,
      resultado: resultado,
      dadosUsuario: dadosUsuario,
    ),
  );
}

/// Detalhes da matéria: nome, código, ementa, créditos, status,
/// pré-requisitos (cada um com seu status) e atalho para as turmas.
class MateriaDetailsSheet extends StatelessWidget {
  final MateriaModel materia;
  final CursoModel curso;
  final ResultadoStatus resultado;
  final DadosMateria? dadosUsuario;

  const MateriaDetailsSheet({
    super.key,
    required this.materia,
    required this.curso,
    required this.resultado,
    this.dadosUsuario,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final status = resultado.statusDe(materia.codigoMateria);
    final preRequisitos = curso.getDirectPrerequisites(materia.codigoMateria);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            materia.codigoMateria,
            style: AppTheme.codigoMateriaStyle(
              fontSize: 13,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(materia.nomeMateria, style: tema.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(texto: status.label, cor: status.cor),
              _Chip(texto: '${materia.creditos} créditos'),
              _Chip(
                texto: materia.nivel > 0
                    ? '${materia.nivel}º semestre'
                    : 'Optativa',
              ),
            ],
          ),
          if (dadosUsuario != null) ...[
            const SizedBox(height: 16),
            _InfoHistorico(dados: dadosUsuario!),
          ],
          const SizedBox(height: 20),
          Text('Ementa', style: tema.titleSmall),
          const SizedBox(height: 6),
          Text(
            materia.ementa.trim().isEmpty
                ? 'Ementa não cadastrada.'
                : materia.ementa.trim(),
            style: tema.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Text('Pré-requisitos', style: tema.titleSmall),
          const SizedBox(height: 6),
          if (preRequisitos.isEmpty)
            Text('Sem pré-requisitos.', style: tema.bodySmall)
          else
            for (final preRequisito in preRequisitos)
              _LinhaPreRequisito(
                materia: preRequisito,
                status: resultado.statusDe(preRequisito.codigoMateria),
              ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.groups_outlined, size: 20),
            label: const Text('Ver turmas'),
            onPressed: () {
              final destino = rotaTurmas(codigo: materia.codigoMateria);
              // Captura o router antes do pop — o context do sheet deixa de
              // estar montado depois que ele fecha.
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.go(destino);
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color? cor;

  const _Chip({required this.texto, this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor ?? AppColors.secondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cor != null ? Colors.white : AppColors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dados do histórico do aluno para esta matéria (menção, professor, período).
class _InfoHistorico extends StatelessWidget {
  final DadosMateria dados;

  const _InfoHistorico({required this.dados});

  @override
  Widget build(BuildContext context) {
    final linhas = <(String, String)>[
      if (dados.mencao.trim().isNotEmpty && dados.mencao.trim() != '-')
        ('Menção', dados.mencao.trim()),
      if ((dados.anoPeriodo ?? '').trim().isNotEmpty)
        ('Período', dados.anoPeriodo!.trim()),
      if (dados.professor.trim().isNotEmpty && dados.professor.trim() != '-')
        ('Professor(a)', dados.professor.trim()),
      if ((dados.codigoEquivalente ?? '').trim().isNotEmpty)
        ('Cumprida por equivalência', dados.codigoEquivalente!.trim()),
    ];
    if (linhas.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (rotulo, valor) in linhas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rotulo: ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      valor,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaPreRequisito extends StatelessWidget {
  final MateriaModel materia;
  final StatusMateria status;

  const _LinhaPreRequisito({required this.materia, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: status.cor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            materia.codigoMateria,
            style: AppTheme.codigoMateriaStyle(fontSize: 11.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              materia.nomeMateria,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
