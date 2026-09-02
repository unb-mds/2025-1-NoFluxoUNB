import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/rotas.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/horario_slots.dart';
import '../data/assistente_repository.dart';
import '../domain/reply_parser.dart';

/// Chat "Darcy" — Assistente IA do NoFluxo, tela cheia.
///
/// A conversa vive NO SERVIDOR (sessão keyed pelo token): o app manda só a
/// mensagem nova e a tela sempre começa limpa, com sugestões. Aberta via
/// `Navigator.push` a partir do FAB do fluxograma — sem rota própria.
class AssistenteScreen extends ConsumerStatefulWidget {
  const AssistenteScreen({super.key});

  @override
  ConsumerState<AssistenteScreen> createState() => _AssistenteScreenState();
}

/// Sugestões mostradas quando a conversa está vazia.
const List<String> _sugestoes = [
  'O que falta para eu me formar?',
  'Me recomenda optativas de IA',
  'Quais turmas de CIC0007 têm vaga?',
];

/// Um item da conversa.
sealed class _ItemChat {
  const _ItemChat();
}

class _ItemUsuario extends _ItemChat {
  final String texto;

  const _ItemUsuario(this.texto);
}

class _ItemDarcy extends _ItemChat {
  final List<BlocoChat> blocos;

  const _ItemDarcy(this.blocos);
}

/// Erro de envio, exibido como mensagem do sistema com "Tentar de novo".
class _ItemErro extends _ItemChat {
  final String mensagem;

  /// Texto do usuário cuja resposta falhou (para o retry).
  final String textoOriginal;

  const _ItemErro(this.mensagem, this.textoOriginal);
}

class _AssistenteScreenState extends ConsumerState<AssistenteScreen> {
  final List<_ItemChat> _mensagens = [];
  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _pensando = false;

  @override
  void dispose() {
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _rolarParaOFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Envia [texto] como nova mensagem do usuário.
  Future<void> _enviar(String texto) async {
    final msg = texto.trim();
    if (msg.isEmpty || _pensando) return;
    _campo.clear();
    setState(() => _mensagens.add(_ItemUsuario(msg)));
    await _processar(msg);
  }

  /// Retry de [item]: some com o erro e reenvia o mesmo texto, sem duplicar
  /// a bolha do usuário (que continua no histórico).
  Future<void> _tentarDeNovo(_ItemErro item) async {
    if (_pensando) return;
    setState(() => _mensagens.remove(item));
    await _processar(item.textoOriginal);
  }

  Future<void> _processar(String msg) async {
    setState(() => _pensando = true);
    _rolarParaOFim();

    // Matriz curricular do histórico do aluno, quando existir — contexto
    // para o orquestrador no backend.
    final curriculo = ref
        .read(authProvider)
        .valueOrNull
        ?.dados
        ?.matrizCurricular;

    try {
      final reply = await ref
          .read(assistenteRepositoryProvider)
          .enviarMensagem(msg, curriculoCompleto: curriculo);
      if (!mounted) return;
      setState(() {
        _pensando = false;
        _mensagens.add(_ItemDarcy(parseReply(reply)));
      });
    } on AssistenteException catch (e) {
      if (!mounted) return;
      setState(() {
        _pensando = false;
        _mensagens.add(_ItemErro(e.mensagem, msg));
      });
    }
    _rolarParaOFim();
  }

  /// Badge tocado: fecha o chat (quando empilhado) e abre a busca de turmas.
  void _abrirTurmas(String codigo) {
    final destino = rotaTurmas(codigo: codigo);
    // Captura o router antes do pop — o context deixa de estar montado
    // depois que a tela empilhada fecha.
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    router.go(destino);
  }

  @override
  Widget build(BuildContext context) {
    final estaLogado = ref.watch(estaLogadoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assistente IA')),
      body: !estaLogado
          ? const _PedirLoginView()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _mensagens.isEmpty && !_pensando
                        ? _SugestoesView(onEnviar: _enviar)
                        : _ListaMensagens(
                            mensagens: _mensagens,
                            pensando: _pensando,
                            scroll: _scroll,
                            onEnviar: _enviar,
                            onTentarDeNovo: _tentarDeNovo,
                            onAbrirTurmas: _abrirTurmas,
                          ),
                  ),
                  _CampoDeMensagem(
                    controller: _campo,
                    enviando: _pensando,
                    onEnviar: _enviar,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Visitante ────────────────────────────────────────────────────────────────

class _PedirLoginView extends StatelessWidget {
  const _PedirLoginView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 40, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              'Entre para conversar com o Darcy',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'O assistente usa o seu histórico para responder — '
              'é preciso estar logado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).maybePop();
                router.go('/login');
              },
              child: const Text('Fazer login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conversa vazia: saudação + sugestões ─────────────────────────────────────

class _SugestoesView extends StatelessWidget {
  final void Function(String) onEnviar;

  const _SugestoesView({required this.onEnviar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome, size: 44, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              'Oi! Eu sou o Darcy',
              textAlign: TextAlign.center,
              style: tema.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Pergunte sobre o seu curso, matérias e turmas.',
              textAlign: TextAlign.center,
              style: tema.bodySmall,
            ),
            const SizedBox(height: 20),
            for (final sugestao in _sugestoes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => onEnviar(sugestao),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(sugestao, style: tema.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de mensagens ───────────────────────────────────────────────────────

class _ListaMensagens extends StatelessWidget {
  final List<_ItemChat> mensagens;
  final bool pensando;
  final ScrollController scroll;
  final void Function(String) onEnviar;
  final void Function(_ItemErro) onTentarDeNovo;
  final void Function(String) onAbrirTurmas;

  const _ListaMensagens({
    required this.mensagens,
    required this.pensando,
    required this.scroll,
    required this.onEnviar,
    required this.onTentarDeNovo,
    required this.onAbrirTurmas,
  });

  @override
  Widget build(BuildContext context) {
    final total = mensagens.length + (pensando ? 1 : 0);
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index >= mensagens.length) return const _PensandoIndicator();
        final item = mensagens[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (item) {
            _ItemUsuario(:final texto) => _BolhaUsuario(texto: texto),
            _ItemDarcy(:final blocos) => _MensagemDarcy(
              blocos: blocos,
              onEnviar: onEnviar,
              onAbrirTurmas: onAbrirTurmas,
            ),
            final _ItemErro erro => _MensagemErro(
              item: erro,
              onTentarDeNovo: () => onTentarDeNovo(erro),
            ),
          },
        );
      },
    );
  }
}

class _BolhaUsuario extends StatelessWidget {
  final String texto;

  const _BolhaUsuario({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radius),
            topRight: Radius.circular(AppTheme.radius),
            bottomLeft: Radius.circular(AppTheme.radius),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.35),
        ),
      ),
    );
  }
}

class _MensagemDarcy extends StatelessWidget {
  final List<BlocoChat> blocos;
  final void Function(String) onEnviar;
  final void Function(String) onAbrirTurmas;

  const _MensagemDarcy({
    required this.blocos,
    required this.onEnviar,
    required this.onAbrirTurmas,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final bloco in blocos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: switch (bloco) {
                  BlocoBolha(:final segmentos) => _BolhaDarcy(
                    segmentos: segmentos,
                    onAbrirTurmas: onAbrirTurmas,
                  ),
                  BlocoTurma(:final turma) => _CardTurma(turma: turma),
                  BlocoBotoes(:final botoes) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final botao in botoes)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            foregroundColor: AppColors.accent,
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.45),
                            ),
                          ),
                          onPressed: () => onEnviar(botao.mensagem),
                          child: Text(botao.label),
                        ),
                    ],
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BolhaDarcy extends StatelessWidget {
  final List<SegmentoChat> segmentos;
  final void Function(String) onAbrirTurmas;

  const _BolhaDarcy({required this.segmentos, required this.onAbrirTurmas});

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radius),
          topRight: Radius.circular(AppTheme.radius),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(AppTheme.radius),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: estilo,
          children: [
            for (final segmento in segmentos)
              switch (segmento) {
                SegmentoTexto(:final valor) => TextSpan(text: valor),
                SegmentoNegrito(:final valor) => TextSpan(
                  text: valor,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                SegmentoBadge(:final codigo) => WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _BadgeMateria(
                    codigo: codigo,
                    onTap: () => onAbrirTurmas(codigo),
                  ),
                ),
              },
          ],
        ),
      ),
    );
  }
}

/// Código de matéria tocável — abre `/turmas?codigo=X`.
class _BadgeMateria extends StatelessWidget {
  final String codigo;
  final VoidCallback onTap;

  const _BadgeMateria({required this.codigo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              codigo,
              style: AppTheme.codigoMateriaStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de turma sugerida (`[TURMA|...]`).
class _CardTurma extends StatelessWidget {
  final TurmaChat turma;

  const _CardTurma({required this.turma});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    // Horário humanizado; EAD / "A DEFINIR" não casa e cai no texto cru.
    final horario = describeHorario(turma.horario);
    final periodo = turma.periodo;

    Widget linha(IconData icone, String texto) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: tema.bodySmall)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Turma ${turma.turma}', style: tema.titleSmall),
              ),
              if (periodo != null && periodo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(periodo, style: tema.labelSmall),
                ),
            ],
          ),
          linha(Icons.person_outline, turma.professor),
          linha(Icons.schedule, horario.isEmpty ? turma.horario : horario),
          linha(Icons.place_outlined, turma.local),
          linha(Icons.event_seat_outlined, '${turma.vagas} vagas'),
        ],
      ),
    );
  }
}

class _MensagemErro extends StatelessWidget {
  final _ItemErro item;
  final VoidCallback onTentarDeNovo;

  const _MensagemErro({required this.item, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.08),
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.destructive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.mensagem,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTentarDeNovo,
                child: const Text('Tentar de novo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "O Darcy está pensando…" com spinner discreto.
class _PensandoIndicator extends StatelessWidget {
  const _PensandoIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'O Darcy está pensando…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Campo de digitação ───────────────────────────────────────────────────────

class _CampoDeMensagem extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final void Function(String) onEnviar;

  const _CampoDeMensagem({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat-campo'),
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onEnviar,
              decoration: const InputDecoration(hintText: 'Pergunte ao Darcy…'),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('chat-enviar'),
            tooltip: 'Enviar',
            icon: Icon(
              Icons.send_rounded,
              color: enviando ? AppColors.mutedForeground : AppColors.accent,
            ),
            onPressed: enviando ? null : () => onEnviar(controller.text),
          ),
        ],
      ),
    );
  }
}
