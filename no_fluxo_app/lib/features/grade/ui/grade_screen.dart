import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/turma_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/horario_slots.dart';
import '../data/aula_notification_scheduler.dart';
import '../data/grade_repository.dart';
import '../domain/grade_builder.dart';
import 'adicionar_turma_sheet.dart';

/// Cor da borda de bloco em conflito de horário.
const Color _corConflito = Color(0xFF991B1B);

/// Tela da grade horária semanal — mobile-first, visão vertical por dia.
///
/// Fontes: matérias MATR do fluxograma (automática) + turmas adicionadas à
/// mão (manual, persistida localmente). O card do topo controla os avisos
/// locais de "aula começando".
class GradeScreen extends ConsumerStatefulWidget {
  const GradeScreen({super.key});

  @override
  ConsumerState<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends ConsumerState<GradeScreen> {
  bool _carregando = true;
  String? _erro;
  List<TurmaGrade> _turmas = const [];

  /// Grade montada uma vez por carga (não a cada build — montar e varrer a
  /// semana inteira em todo rebuild seria desperdício).
  GradeSemanal _grade = montarGradeSemanal(const []);
  ConfigNotificacaoAulas _config = const ConfigNotificacaoAulas();
  AuthState? _authAtual;

  /// Fatia do auth que a grade de fato consome — recarregar só quando ela
  /// muda (e não em qualquer emissão do [authProvider]).
  ({AuthStatus status, int? idUser})? _chaveAuth;

  int get _idUser => _authAtual?.user?.idUser ?? 0;

  Future<void> _carregar(AuthState auth) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final repo = ref.read(gradeRepositoryProvider);
      final scheduler = ref.read(aulaNotificationSchedulerProvider);
      final turmas = await repo.carregarGrade(
        dados: auth.dados,
        idUser: auth.user?.idUser ?? 0,
      );
      final config = await scheduler.carregarConfig();
      if (!mounted) return;
      setState(() {
        _turmas = turmas;
        _grade = montarGradeSemanal(turmas);
        _config = config;
        _carregando = false;
      });
      unawaited(scheduler.sincronizar(turmas));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar sua grade.';
        _carregando = false;
      });
    }
  }

  // ── Notificações ───────────────────────────────────────────────────────────

  Future<void> _alterarNotificacoes({
    bool? ativas,
    int? antecedenciaMin,
  }) async {
    final scheduler = ref.read(aulaNotificationSchedulerProvider);
    final nova = _config.copyWith(
      ativas: ativas,
      antecedenciaMin: antecedenciaMin,
    );

    // Ligar o toggle pede permissão/inicializa o plugin antes de gravar.
    if (ativas == true && !await scheduler.init()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível ativar as notificações.'),
        ),
      );
      return;
    }

    await scheduler.salvarConfig(nova);
    if (!mounted) return;
    setState(() => _config = nova);
    unawaited(scheduler.sincronizar(_turmas));
  }

  // ── Grade manual ───────────────────────────────────────────────────────────

  Future<void> _abrirAdicionarTurma() async {
    final turma = await showModalBottomSheet<TurmaModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const AdicionarTurmaSheet(),
    );
    if (turma == null || !mounted) return;
    await _adicionarTurma(turma);
  }

  Future<void> _adicionarTurma(TurmaModel turma) async {
    try {
      // Aviso de conflito antes de gravar (a turma entra mesmo assim — o
      // conflito fica visível na grade, decisão do aluno).
      final maskNova = parseHorarioToMask(turma.horario);
      final conflita = _turmas.any(
        (t) => masksConflict(maskNova, parseHorarioToMask(t.turma.horario)),
      );

      await ref
          .read(gradeRepositoryProvider)
          .adicionarTurmaManual(idUser: _idUser, turma: turma);
      if (!mounted) return;
      if (conflita) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Atenção: o horário conflita com outra turma da grade.',
            ),
          ),
        );
      }
      final auth = _authAtual;
      if (auth != null) await _carregar(auth);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar a turma.')),
      );
    }
  }

  Future<void> _removerTurma(int idTurmas, String codigo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover turma'),
        content: Text('Remover $codigo da sua grade?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    await ref
        .read(gradeRepositoryProvider)
        .removerTurmaManual(idUser: _idUser, idTurmas: idTurmas);
    if (!mounted) return;
    final auth = _authAtual;
    if (auth != null) await _carregar(auth);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncAuth = ref.watch(authProvider);
    final auth = asyncAuth.valueOrNull;

    // Primeira carga (e recarga quando a fatia de auth que a grade consome
    // muda — status/usuário; outras emissões do provider não recarregam).
    if (auth != null) {
      _authAtual = auth;
      final chave = (status: auth.status, idUser: auth.user?.idUser);
      if (chave != _chaveAuth) {
        _chaveAuth = chave;
        Future.microtask(() {
          if (mounted) _carregar(auth);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grade horária')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: auth == null ? null : _abrirAdicionarTurma,
        icon: const Icon(Icons.add),
        label: const Text('Turma'),
      ),
      body: auth == null || _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? _EstadoErro(
              mensagem: _erro!,
              onTentarNovamente: () => _carregar(auth),
            )
          : _corpo(auth),
    );
  }

  Widget _corpo(AuthState auth) {
    final grade = _grade;
    final destaque = aulaEmDestaque(grade, DateTime.now());

    return RefreshIndicator(
      onRefresh: () => _carregar(auth),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _CardConfiguracao(
            config: _config,
            onAtivasChanged: (v) => _alterarNotificacoes(ativas: v),
            onAntecedenciaChanged: (min) =>
                _alterarNotificacoes(antecedenciaMin: min),
          ),
          const SizedBox(height: 16),
          if (grade.vazia)
            _EstadoVazio(visitante: auth.isVisitante)
          else ...[
            for (final weekday in grade.diasComAula) ...[
              _CabecalhoDia(bloco: grade.blocosPorDia[weekday]!.first),
              for (final bloco in grade.blocosPorDia[weekday]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CardAula(
                    bloco: bloco,
                    emDestaque:
                        destaque != null && identical(destaque.bloco, bloco),
                    emAndamento:
                        destaque != null &&
                        identical(destaque.bloco, bloco) &&
                        destaque.emAndamento,
                    onRemover: bloco.manual
                        ? () => _removerTurma(bloco.idTurmas, bloco.codigo)
                        : null,
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (grade.semHorario.isNotEmpty)
              _SecaoSemHorario(
                turmas: grade.semHorario,
                onRemover: (t) => _removerTurma(
                  t.turma.idTurmas,
                  t.turma.codigoMateria ?? t.turma.turma,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────────

/// Card do topo: toggle de aviso + antecedência (10/30/60 min).
class _CardConfiguracao extends StatelessWidget {
  final ConfigNotificacaoAulas config;
  final ValueChanged<bool> onAtivasChanged;
  final ValueChanged<int> onAntecedenciaChanged;

  const _CardConfiguracao({
    required this.config,
    required this.onAtivasChanged,
    required this.onAntecedenciaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Avisar antes da aula')),
              Switch(value: config.ativas, onChanged: onAtivasChanged),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final min in const [10, 30, 60])
                ChoiceChip(
                  label: Text('$min min'),
                  selected: config.antecedenciaMin == min,
                  onSelected: config.ativas
                      ? (_) => onAntecedenciaChanged(min)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho da seção de um dia ("Seg", "Ter"...).
class _CabecalhoDia extends StatelessWidget {
  final BlocoAula bloco;

  const _CabecalhoDia({required this.bloco});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        bloco.diaLabel,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.accent,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Card de um bloco de aula. Borda roxa = aula atual/próxima; borda vermelha
/// escura = conflito de horário.
class _CardAula extends StatelessWidget {
  final BlocoAula bloco;
  final bool emDestaque;
  final bool emAndamento;
  final VoidCallback? onRemover;

  const _CardAula({
    required this.bloco,
    required this.emDestaque,
    required this.emAndamento,
    this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final corBorda = bloco.conflito
        ? _corConflito
        : emDestaque
        ? AppColors.primary
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: corBorda,
          width: bloco.conflito || emDestaque ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna de horário.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bloco.inicio,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                bloco.fim,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bloco.codigo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'T${bloco.turmaLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    if (emDestaque) ...[
                      const SizedBox(width: 6),
                      _Etiqueta(
                        texto: emAndamento ? 'agora' : 'próxima',
                        cor: AppColors.primary,
                      ),
                    ],
                    if (bloco.conflito) ...[
                      const SizedBox(width: 6),
                      const _Etiqueta(texto: 'conflito', cor: _corConflito),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(bloco.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
                if ((bloco.local ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            bloco.local!.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onRemover != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              tooltip: 'Remover turma',
              onPressed: onRemover,
            ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;

  const _Etiqueta({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor),
      ),
      child: Text(texto, style: TextStyle(fontSize: 10, color: cor)),
    );
  }
}

/// Turmas EAD / sem horário definido (não entram nos blocos por dia).
class _SecaoSemHorario extends StatelessWidget {
  final List<TurmaGrade> turmas;
  final ValueChanged<TurmaGrade> onRemover;

  const _SecaoSemHorario({required this.turmas, required this.onRemover});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Sem horário definido',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ),
        for (final t in turmas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              '${t.turma.codigoMateria ?? '—'} · Turma ${t.turma.turma}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            subtitle: Text(t.turma.nomeMateria ?? 'Horário a definir / EAD'),
            trailing: t.manual
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => onRemover(t),
                  )
                : null,
          ),
      ],
    );
  }
}

/// Estado vazio: sem turmas na grade (visitante ou aluno sem MATR).
class _EstadoVazio extends StatelessWidget {
  final bool visitante;

  const _EstadoVazio({required this.visitante});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.calendar_view_week_outlined,
              size: 48,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sua grade está vazia',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            visitante
                ? 'No modo visitante a grade não é importada automaticamente. '
                      'Use o botão "+ Turma" para montar sua grade — ou entre na '
                      'sua conta e envie o histórico para preencher tudo sozinho.'
                : 'Envie seu histórico no fluxograma para importar as matérias '
                      'em curso, ou toque em "+ Turma" para adicionar turmas '
                      'manualmente.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const _EstadoErro({required this.mensagem, required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mensagem),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTentarNovamente,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
