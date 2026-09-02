import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curso_model.dart';
import '../../../core/models/materia_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../assistente/ui/assistente_screen.dart';
import '../data/fluxograma_repository.dart';
import '../domain/status_resolver.dart';
import 'materia_details_sheet.dart';

// ── Providers da tela ────────────────────────────────────────────────────────

/// Cursos disponíveis para o seletor (visitante / sem fluxograma salvo).
///
/// Observa o status de auth: sob RLS o visitante pode receber lista vazia e,
/// depois do login, a mesma query passa a retornar os cursos — sem o watch, a
/// lista vazia ficaria cacheada até reiniciar o app.
final cursosDisponiveisProvider = FutureProvider<List<CursoResumo>>((ref) {
  ref.watch(authProvider.select((auth) => auth.valueOrNull?.status));
  return ref.watch(fluxogramaRepositoryProvider).buscarCursos();
});

/// Curso escolhido manualmente no seletor (null = nenhum).
final cursoSelecionadoProvider = StateProvider<CursoResumo?>((ref) => null);

/// Matriz escolhida manualmente (null = usa a mais recente do curso).
final matrizSelecionadaProvider = StateProvider<MatrizResumo?>((ref) => null);

/// "Trocar curso": ignora o fluxograma do aluno e mostra o seletor.
final trocandoCursoProvider = StateProvider<bool>((ref) => false);

/// Curso/matriz efetivamente exibidos no fluxograma.
///
/// Prioridade: seleção manual (permite "trocar curso" mesmo logado) →
/// matriz do histórico do aluno (`dados.matrizCurricular`, com fallback pelo
/// nome do curso) → null (mostra o seletor).
final fluxogramaExibidoProvider = FutureProvider<CursoModel?>((ref) async {
  final repo = ref.watch(fluxogramaRepositoryProvider);

  final matrizManual = ref.watch(matrizSelecionadaProvider);
  if (matrizManual != null) return repo.buscarCursoDaMatriz(matrizManual);

  final cursoManual = ref.watch(cursoSelecionadoProvider);
  if (cursoManual != null) {
    final matrizes = await repo.buscarMatrizes(cursoManual.idCurso);
    if (matrizes.isEmpty) return null;
    return repo.buscarCursoDaMatriz(matrizes.first);
  }

  // "Trocar curso" sem nova seleção ainda: mostra o seletor.
  if (ref.watch(trocandoCursoProvider)) return null;

  final dados = ref.watch(
    authProvider.select((auth) => auth.valueOrNull?.dados),
  );
  if (dados != null) {
    var matriz = await repo.buscarMatrizPorCurriculo(dados.matrizCurricular);
    if (matriz == null && dados.nomeCurso.trim().isNotEmpty) {
      // Fallback: primeira matriz do curso com o mesmo nome do histórico.
      final alvo = dados.nomeCurso.trim().toUpperCase();
      final cursos = await repo.buscarCursos();
      for (final curso in cursos) {
        if (curso.nomeCurso.trim().toUpperCase() != alvo) continue;
        final matrizes = await repo.buscarMatrizes(curso.idCurso);
        if (matrizes.isNotEmpty) matriz = matrizes.first;
        break;
      }
    }
    if (matriz != null) return repo.buscarCursoDaMatriz(matriz);
  }

  return null;
});

/// Derivação pura do fluxograma exibido: status resolvido + colunas por
/// semestre, calculados FORA do build da tela.
///
/// Sem isso, `resolverStatus` (expansão de equivalências + avaliação das
/// expressões E/OU de cada matéria) rodaria a cada rebuild — inclusive nos
/// causados por emissões de auth sem mudança real. Aqui o cálculo só refaz
/// quando curso, histórico ou seleção manual mudam de fato; a tela só lê.
final resultadoStatusProvider = Provider<FluxogramaResolvido?>((ref) {
  final curso = ref.watch(fluxogramaExibidoProvider).valueOrNull;
  if (curso == null) return null;

  // Histórico do aluno só colore o fluxograma quando ele vê o próprio
  // curso — num curso escolhido manualmente o fluxograma é genérico.
  final selecaoManual =
      ref.watch(cursoSelecionadoProvider) != null ||
      ref.watch(matrizSelecionadaProvider) != null;
  final dados = selecaoManual
      ? null
      : ref.watch(authProvider.select((auth) => auth.valueOrNull?.dados));

  final resultado = resolverStatus(curso: curso, dados: dados);
  return FluxogramaResolvido(
    curso: curso,
    dados: dados,
    resultado: resultado,
    colunas: _montarColunas(curso, resultado),
  );
});

/// Curso pronto para exibição: status por matéria e colunas já montadas.
class FluxogramaResolvido {
  final CursoModel curso;

  /// Histórico efetivamente aplicado (null na visão genérica/manual).
  final DadosFluxogramaUser? dados;
  final ResultadoStatus resultado;
  final List<DadosColuna> colunas;

  const FluxogramaResolvido({
    required this.curso,
    required this.dados,
    required this.resultado,
    required this.colunas,
  });
}

/// Coluna do fluxograma: um semestre (ou "Optativas") e suas matérias.
class DadosColuna {
  final String titulo;
  final List<MateriaModel> materias;

  const DadosColuna({required this.titulo, required this.materias});
}

List<DadosColuna> _montarColunas(CursoModel curso, ResultadoStatus resultado) {
  final porNivel = <int, List<MateriaModel>>{};
  for (final materia in curso.materias) {
    porNivel.putIfAbsent(materia.nivel, () => []).add(materia);
  }

  final colunas = <DadosColuna>[];
  for (var nivel = 1; nivel <= curso.semestres; nivel++) {
    final materias = porNivel[nivel] ?? const <MateriaModel>[];
    if (materias.isEmpty) continue;
    materias.sort((a, b) => a.codigoMateria.compareTo(b.codigoMateria));
    colunas.add(DadosColuna(titulo: '$nivelº semestre', materias: materias));
  }

  // Optativas (nivel 0): só as que aparecem no histórico do aluno — listar
  // a matriz inteira de optativas inviabiliza a leitura no celular.
  final optativas =
      (porNivel[0] ?? const <MateriaModel>[])
          .where(
            (materia) => switch (resultado.statusDe(materia.codigoMateria)) {
              StatusMateria.concluida ||
              StatusMateria.emCurso ||
              StatusMateria.reprovada => true,
              _ => false,
            },
          )
          .toList()
        ..sort((a, b) => a.codigoMateria.compareTo(b.codigoMateria));
  if (optativas.isNotEmpty) {
    colunas.add(DadosColuna(titulo: 'Optativas', materias: optativas));
  }
  return colunas;
}

// ── Tela ─────────────────────────────────────────────────────────────────────

/// Zera a seleção manual de curso/matriz; [trocando] decide se a tela cai no
/// seletor ("trocar curso") ou volta à visão personalizada do aluno.
void _resetarSelecao(WidgetRef ref, {required bool trocando}) {
  ref.read(matrizSelecionadaProvider.notifier).state = null;
  ref.read(cursoSelecionadoProvider.notifier).state = null;
  ref.read(trocandoCursoProvider.notifier).state = trocando;
}

/// Fluxograma do curso, mobile-first: colunas por semestre com scroll
/// horizontal e cards coloridos por status.
class FluxogramaScreen extends ConsumerWidget {
  const FluxogramaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(
      authProvider.select((auth) => auth.valueOrNull?.dados),
    );
    final cursoAsync = ref.watch(fluxogramaExibidoProvider);
    final resolvido = ref.watch(resultadoStatusProvider);

    final selecaoManual =
        ref.watch(cursoSelecionadoProvider) != null ||
        ref.watch(matrizSelecionadaProvider) != null;
    final trocandoCurso = ref.watch(trocandoCursoProvider);

    final exibindoFluxograma = cursoAsync.valueOrNull != null;
    final estaLogado = ref.watch(estaLogadoProvider);

    return Scaffold(
      // Assistente IA (chat "Darcy"): só para logados — o endpoint exige o
      // token do Supabase. Aberto por push, sem rota própria.
      floatingActionButton: estaLogado
          ? FloatingActionButton(
              tooltip: 'Assistente IA',
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF1A0B2E),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssistenteScreen()),
              ),
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      appBar: AppBar(
        title: const Text('Fluxograma'),
        actions: [
          // "Trocar curso" é reversível para o aluno com fluxograma próprio:
          // zera a seleção manual e volta à visão personalizada, sem
          // precisar reiniciar o app.
          if (dados != null && (selecaoManual || trocandoCurso))
            IconButton(
              tooltip: 'Voltar ao meu fluxograma',
              icon: const Icon(Icons.undo),
              onPressed: () => _resetarSelecao(ref, trocando: false),
            ),
          if (exibindoFluxograma)
            IconButton(
              tooltip: 'Trocar curso',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _resetarSelecao(ref, trocando: true),
            ),
        ],
      ),
      body: cursoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => _AvisoView(
          icone: Icons.error_outline,
          corIcone: AppColors.destructive,
          mensagem: 'Não foi possível carregar o fluxograma.\n$erro',
          onTentarNovamente: () => ref.invalidate(fluxogramaExibidoProvider),
        ),
        data: (curso) => curso == null || resolvido == null
            ? const _SeletorDeCurso()
            : _FluxogramaView(resolvido: resolvido),
      ),
    );
  }
}

// ── Seletor de curso (visitante / sem fluxograma salvo) ──────────────────────

class _SeletorDeCurso extends ConsumerWidget {
  const _SeletorDeCurso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursosAsync = ref.watch(cursosDisponiveisProvider);

    return cursosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => _AvisoView(
        icone: Icons.error_outline,
        corIcone: AppColors.destructive,
        mensagem: 'Não foi possível carregar os cursos.\n$erro',
        onTentarNovamente: () => ref.invalidate(cursosDisponiveisProvider),
      ),
      // Lista vazia (sem conexão ou RLS restrito para visitante): estado
      // explicativo com retry, nunca tela em branco.
      data: (cursos) => cursos.isEmpty
          ? _AvisoView(
              icone: Icons.school_outlined,
              corIcone: AppColors.mutedForeground,
              mensagem:
                  'Não foi possível carregar os cursos.\n'
                  'Sem conexão ou acesso restrito — entre com sua conta '
                  'para continuar.',
              onTentarNovamente: () =>
                  ref.invalidate(cursosDisponiveisProvider),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Escolha um curso para ver o fluxograma da matriz.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: cursos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final curso = cursos[index];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          onTap: () {
                            ref.read(matrizSelecionadaProvider.notifier).state =
                                null;
                            ref.read(cursoSelecionadoProvider.notifier).state =
                                curso;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 20,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        curso.nomeCurso,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      // Distingue homônimos (diurno/noturno).
                                      if (curso.detalhe.isNotEmpty)
                                        Text(
                                          curso.detalhe,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: AppColors.mutedForeground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Fluxograma ───────────────────────────────────────────────────────────────

class _FluxogramaView extends StatelessWidget {
  final FluxogramaResolvido resolvido;

  const _FluxogramaView({required this.resolvido});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          curso: resolvido.curso,
          dados: resolvido.dados,
          resultado: resolvido.resultado,
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final coluna in resolvido.colunas)
                    _ColunaSemestre(
                      coluna: coluna,
                      curso: resolvido.curso,
                      dados: resolvido.dados,
                      resultado: resolvido.resultado,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final CursoModel curso;
  final DadosFluxogramaUser? dados;
  final ResultadoStatus resultado;

  const _Header({
    required this.curso,
    required this.dados,
    required this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final progresso = progressoDoCurso(curso, resultado);
    final obrigatorias = curso.materias
        .where((materia) => materia.nivel > 0)
        .length;
    final concluidas = curso.materias
        .where(
          (materia) =>
              materia.nivel > 0 &&
              resultado.statusDe(materia.codigoMateria) ==
                  StatusMateria.concluida,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            curso.nomeCurso,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tema.titleMedium,
          ),
          const SizedBox(height: 8),
          if (dados != null) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progresso,
                      minHeight: 8,
                      backgroundColor: AppColors.secondary,
                      color: AppColors.materiaCompleted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(progresso * 100).round()}%', style: tema.labelLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$concluidas de $obrigatorias obrigatórias concluídas',
              style: tema.bodySmall,
            ),
          ] else
            Text(
              'Fluxograma genérico da matriz ${curso.matrizCurricular}',
              style: tema.bodySmall,
            ),
          const SizedBox(height: 8),
          const _Legenda(),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    const itens = [
      StatusMateria.concluida,
      StatusMateria.emCurso,
      StatusMateria.disponivel,
      StatusMateria.reprovada,
      StatusMateria.bloqueada,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final status in itens)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status.cor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ColunaSemestre extends StatelessWidget {
  final DadosColuna coluna;
  final CursoModel curso;
  final DadosFluxogramaUser? dados;
  final ResultadoStatus resultado;

  const _ColunaSemestre({
    required this.coluna,
    required this.curso,
    required this.dados,
    required this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    final creditos = coluna.materias.fold<int>(
      0,
      (soma, materia) => soma + materia.creditos,
    );

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(coluna.titulo, style: Theme.of(context).textTheme.titleSmall),
          Text(
            '$creditos créditos',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          for (final materia in coluna.materias)
            _MateriaCard(
              materia: materia,
              status: resultado.statusDe(materia.codigoMateria),
              onTap: () => mostrarDetalhesMateria(
                context,
                materia: materia,
                curso: curso,
                resultado: resultado,
                dadosUsuario: encontrarDadosDaMateria(
                  dados,
                  materia.codigoMateria,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MateriaCard extends StatelessWidget {
  final MateriaModel materia;
  final StatusMateria status;
  final VoidCallback onTap;

  const _MateriaCard({
    required this.materia,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: status.cor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materia.codigoMateria,
                  style: AppTheme.codigoMateriaStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  materia.nomeMateria,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${materia.creditos} cr',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (status == StatusMateria.bloqueada)
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Aviso com retentativa ────────────────────────────────────────────────────

/// Aviso centralizado (ícone + mensagem + "Tentar novamente"), usado tanto
/// para erros quanto para a lista de cursos vazia — nunca tela em branco.
class _AvisoView extends StatelessWidget {
  final IconData icone;
  final Color corIcone;
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const _AvisoView({
    required this.icone,
    required this.corIcone,
    required this.mensagem,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 40, color: corIcone),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onTentarNovamente,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
