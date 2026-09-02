import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/materia_model.dart';
import '../../../core/models/turma_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/horario_slots.dart';
import '../data/turmas_providers.dart';
import '../domain/turmas_logic.dart';
import 'minhas_assinaturas_section.dart';
import '../../../core/widgets/vagas_badge.dart';

/// Tela de Turmas (mobile-first): busca de matérias por código ou nome,
/// oferta do período atual com vagas ao vivo e alertas "avisar quando abrir
/// vaga" (por matéria ou por turma específica).
class TurmasScreen extends ConsumerStatefulWidget {
  /// Código vindo do query param `?codigo=` da rota — pré-preenche a busca.
  final String? codigoInicial;

  const TurmasScreen({super.key, this.codigoInicial});

  @override
  ConsumerState<TurmasScreen> createState() => _TurmasScreenState();
}

class _TurmasScreenState extends ConsumerState<TurmasScreen> {
  final TextEditingController _buscaController = TextEditingController();
  Timer? _debounce;

  /// Termo efetivo da busca (atualizado após o debounce).
  String _termo = '';

  /// Matéria selecionada na lista de resultados (null = mostrando resultados).
  MateriaModel? _materiaSelecionada;

  @override
  void initState() {
    super.initState();
    _aplicarCodigoInicial(widget.codigoInicial);
  }

  @override
  void didUpdateWidget(covariant TurmasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Navegação para /turmas?codigo=X com a tela já montada.
    if (widget.codigoInicial != oldWidget.codigoInicial) {
      setState(() => _aplicarCodigoInicial(widget.codigoInicial));
    }
  }

  /// Pré-preenche a busca com o código vindo da rota (sem debounce).
  void _aplicarCodigoInicial(String? codigo) {
    final limpo = (codigo ?? '').trim();
    if (limpo.isEmpty) return;
    _buscaController.text = limpo;
    _termo = limpo;
    _materiaSelecionada = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _onBuscaChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _termo = valor;
        _materiaSelecionada = null;
      });
    });
  }

  void _limparBusca() {
    _debounce?.cancel();
    _buscaController.clear();
    setState(() {
      _termo = '';
      _materiaSelecionada = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Turmas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buscar'),
              Tab(text: 'Seguindo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildAbaBusca(), const MinhasAssinaturasSection()],
        ),
      ),
    );
  }

  Widget _buildAbaBusca() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _buscaController,
            onChanged: _onBuscaChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Código (CIC0004) ou nome da matéria',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscaController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close),
                      onPressed: _limparBusca,
                    ),
            ),
          ),
        ),
        Expanded(child: _buildConteudoBusca()),
      ],
    );
  }

  Widget _buildConteudoBusca() {
    final materia = _materiaSelecionada;
    if (materia != null) {
      return _TurmasDaMateriaView(
        materia: materia,
        onVoltar: () => setState(() => _materiaSelecionada = null),
      );
    }

    if (!termoBuscavel(_termo)) {
      return const _Dica(
        icone: Icons.search,
        texto:
            'Busque uma matéria pelo código ou nome para ver as turmas '
            'ofertadas e as vagas em tempo real.',
      );
    }

    final resultados = ref.watch(buscarMateriasProvider(_termo));
    return resultados.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _Dica(
        icone: Icons.error_outline,
        texto: 'Erro ao buscar matérias. Verifique sua conexão.',
      ),
      data: (materias) {
        if (materias.isEmpty) {
          // Sob RLS o visitante recebe lista vazia SEM erro em toda busca —
          // dizer "nenhuma matéria encontrada" seria mentira confusa.
          if (!ref.watch(estaLogadoProvider)) {
            return const _Dica(
              icone: Icons.lock_outline,
              texto:
                  'Entre com sua conta para buscar turmas — o acesso sem '
                  'login ainda não está liberado.',
            );
          }
          return const _Dica(
            icone: Icons.search_off,
            texto: 'Nenhuma matéria encontrada para essa busca.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: materias.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final m = materias[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surface,
              title: Text(
                m.codigoMateria,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                m.nomeMateria,
                style: const TextStyle(color: AppColors.foreground),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.mutedForeground,
              ),
              onTap: () => setState(() => _materiaSelecionada = m),
            );
          },
        );
      },
    );
  }
}

/// Detalhe de uma matéria: botão de seguir a matéria inteira + lista de
/// turmas ofertadas no período atual.
class _TurmasDaMateriaView extends ConsumerWidget {
  final MateriaModel materia;
  final VoidCallback onVoltar;

  const _TurmasDaMateriaView({required this.materia, required this.onVoltar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turmas = ref.watch(turmasDaMateriaProvider(materia.idMateria));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar para os resultados',
              icon: const Icon(Icons.arrow_back),
              onPressed: onVoltar,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    materia.codigoMateria,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    materia.nomeMateria,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Seguir a matéria inteira: qualquer turma que abrir vaga avisa.
        SeguirVagaButton(
          idMateria: materia.idMateria,
          turma: null,
          expandido: true,
        ),
        const SizedBox(height: 16),
        turmas.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const _Dica(
            icone: Icons.error_outline,
            texto: 'Erro ao carregar as turmas. Tente novamente.',
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const _Dica(
                icone: Icons.event_busy,
                texto: 'Nenhuma turma ofertada no período atual.',
              );
            }
            return Column(
              children: [
                for (final t in lista) ...[
                  _TurmaCard(turma: t),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Card de uma turma: docente, horário humanizado, local, badge de vagas,
/// frescor do dado e botão de seguir a turma específica.
class _TurmaCard extends StatelessWidget {
  final TurmaModel turma;

  const _TurmaCard({required this.turma});

  @override
  Widget build(BuildContext context) {
    final horario = describeHorario(turma.horario);
    final atualizado = descreverAtualizadoHa(turma.lastUpdatedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Turma ${turma.turma}',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              VagasBadge(vagasSobrando: turma.vagasSobrando),
            ],
          ),
          const SizedBox(height: 8),
          if ((turma.docente ?? '').isNotEmpty)
            _LinhaInfo(icone: Icons.person_outline, texto: turma.docente!),
          _LinhaInfo(
            icone: Icons.schedule,
            texto: horario.isEmpty ? 'Horário a definir' : horario,
          ),
          if ((turma.local ?? '').isNotEmpty)
            _LinhaInfo(icone: Icons.place_outlined, texto: turma.local!),
          if (turma.vagasOfertadas != null)
            _LinhaInfo(
              icone: Icons.groups_outlined,
              texto:
                  '${turma.vagasOcupadas ?? 0} ocupadas de '
                  '${turma.vagasOfertadas} ofertadas',
            ),
          if (atualizado.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              atualizado,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SeguirVagaButton(
            idMateria: turma.idMateria,
            turma: turma.turma,
            anoPeriodo: turma.anoPeriodo,
          ),
        ],
      ),
    );
  }
}

/// Botão de alerta de vaga (por matéria quando [turma] é null, por turma
/// específica caso contrário). Alterna entre seguir e deixar de seguir;
/// desabilitado com dica quando o usuário não está logado.
class SeguirVagaButton extends ConsumerWidget {
  final int idMateria;

  /// Turma específica; null = qualquer turma da matéria.
  final String? turma;

  /// Período da assinatura. Null → resolve via RPC `periodo_letivo_atual`.
  final String? anoPeriodo;

  /// Ocupa a largura toda (variante da matéria inteira).
  final bool expandido;

  const SeguirVagaButton({
    super.key,
    required this.idMateria,
    this.turma,
    this.anoPeriodo,
    this.expandido = false,
  });

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(assinaturasProvider.notifier);
    final assinaturas = ref.read(assinaturasProvider).valueOrNull ?? const [];
    final assinatura = assinaturaDe(
      assinaturas,
      idMateria: idMateria,
      turma: turma,
    );

    String? erro;
    if (assinatura != null) {
      erro = await notifier.deixarDeSeguir(assinatura.idAssinatura);
    } else {
      // O fallback por data mora no PeriodoLetivo (core) — o repository
      // nunca lança por RPC fora do ar.
      final String periodo =
          anoPeriodo ?? await ref.read(periodoAtualProvider.future);
      erro = await notifier.seguir(
        idMateria: idMateria,
        turma: turma,
        anoPeriodo: periodo,
      );
    }
    if (erro != null) {
      messenger?.showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logado = ref.watch(estaLogadoProvider);
    // select: seguir 1 turma não deve rebuildar os botões das outras N.
    final seguindo = ref.watch(
      assinaturasProvider.select(
        (a) =>
            assinaturaDe(
              a.valueOrNull ?? const [],
              idMateria: idMateria,
              turma: turma,
            ) !=
            null,
      ),
    );

    final label = seguindo
        ? 'Seguindo — toque para desfazer'
        : turma == null
        ? 'Avisar quando abrir vaga (qualquer turma)'
        : 'Avisar quando abrir vaga';
    final icone = Icon(
      seguindo ? Icons.notifications_active : Icons.notifications_none,
      size: 18,
    );
    final onPressed = logado ? () => _onTap(context, ref) : null;

    // Mesmo botão nos dois estados; só o estilo muda quando seguindo.
    final Widget botao = seguindo
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.foreground,
            ),
            onPressed: onPressed,
            icon: icone,
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.border),
            ),
            onPressed: onPressed,
            icon: icone,
            label: Text(label),
          );

    return Column(
      crossAxisAlignment: expandido
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        botao,
        if (!logado)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Entre para ser avisado',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _LinhaInfo({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: AppColors.foreground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dica extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Dica({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 44, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
