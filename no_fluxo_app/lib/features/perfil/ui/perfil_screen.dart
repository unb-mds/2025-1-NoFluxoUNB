import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/release.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../suporte/ui/suporte_screen.dart';
import '../data/perfil_repository.dart';
import '../domain/progresso_calculator.dart';
import 'novidades_dialog.dart';

/// Tela de Perfil (mobile-first, dark).
///
/// Logado: header com avatar/curso, cards de progresso por natureza, IRA,
/// semestre, contagens de matérias, card de estado do histórico (importar /
/// reenviar / ok) e seção de conta (suporte, novidades, sair). Visitante:
/// convite para entrar.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final estado = auth.valueOrNull;

    final Widget corpo;
    if (estado == null) {
      // Boot do app: sessão ainda resolvendo.
      corpo = const Center(child: CircularProgressIndicator());
    } else if (estado.isLoggedIn && estado.user != null) {
      corpo = PerfilLogadoView(user: estado.user!);
    } else if (estado.isLoggedIn) {
      // Sessão válida mas perfil inacessível (boot offline) — NÃO é
      // visitante: mostra o estado real, com saída que remove o token push.
      corpo = const PerfilOfflineView();
    } else {
      corpo = const PerfilVisitanteView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: corpo,
    );
  }
}

// ─── Logado sem perfil (boot offline) ────────────────────────────────────────

/// Sessão Supabase válida, mas o perfil ainda não pôde ser carregado (sem
/// rede no boot). O retry automático do AuthNotifier resolve sozinho quando a
/// conexão volta; aqui só damos visibilidade e uma saída limpa.
class PerfilOfflineView extends ConsumerWidget {
  const PerfilOfflineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              'Você está conectado, mas seu perfil ainda não pôde ser '
              'carregado. Verifique sua conexão — tentaremos de novo '
              'sozinhos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(
              // O unregister do push acontece dentro do logout (core).
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('Sair da conta'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logado ──────────────────────────────────────────────────────────────────

/// Conteúdo da tela para usuário logado. Recebe o [UserModel] pronto e busca o
/// progresso via [progressoPerfilProvider] (override nos testes).
///
/// Stateful pelo dialog de novidades: disparado uma única vez após o
/// primeiro frame (uma vez por usuário+release — ver novidades_dialog.dart).
class PerfilLogadoView extends ConsumerStatefulWidget {
  final UserModel user;

  const PerfilLogadoView({super.key, required this.user});

  @override
  ConsumerState<PerfilLogadoView> createState() => _PerfilLogadoViewState();
}

class _PerfilLogadoViewState extends ConsumerState<PerfilLogadoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarNovidadesSeNecessario(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final progresso = ref.watch(progressoPerfilProvider);
    final dados = user.dadosFluxograma;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeaderPerfil(user: user, dados: dados),
        const SizedBox(height: 20),
        progresso.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const _CardMensagem(
            icone: Icons.cloud_off_outlined,
            texto:
                'Não foi possível carregar seu progresso. '
                'Verifique sua conexão e tente novamente.',
          ),
          data: (p) => p == null
              ? const SizedBox.shrink()
              : _SecaoProgresso(progresso: p, dados: dados),
        ),
        const SizedBox(height: 20),
        CardHistorico(dados: dados),
        const SizedBox(height: 20),
        const _SecaoConta(),
        const SizedBox(height: 24),
        const _Rodape(),
      ],
    );
  }
}

/// Avatar com iniciais + nome, e-mail e curso/matriz.
class _HeaderPerfil extends StatelessWidget {
  final UserModel user;
  final DadosFluxogramaUser? dados;

  const _HeaderPerfil({required this.user, this.dados});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final curso = dados?.nomeCurso ?? '';
    final matriz = dados?.matrizCurricular ?? '';

    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primary,
          child: Text(
            iniciaisDoNome(user.nomeCompleto),
            style: tema.headlineSmall?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.nomeCompleto,
          style: tema.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          style: tema.bodySmall?.copyWith(color: AppColors.mutedForeground),
          textAlign: TextAlign.center,
        ),
        if (curso.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              matriz.isNotEmpty ? '$curso • $matriz' : curso,
              style: tema.labelMedium?.copyWith(
                color: AppColors.accent,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

/// Cards de progresso: barras por natureza + IRA/semestre + matérias.
class _SecaoProgresso extends StatelessWidget {
  final ProgressoPerfil progresso;
  final DadosFluxogramaUser? dados;

  const _SecaoProgresso({required this.progresso, this.dados});

  @override
  Widget build(BuildContext context) {
    final iraTexto = _formatarIra(dados);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progresso do curso',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _BarraNatureza(
                  label: 'Total',
                  natureza: progresso.total,
                  cor: AppColors.primary,
                ),
                const SizedBox(height: 14),
                _BarraNatureza(
                  label: 'Obrigatória',
                  natureza: progresso.obrigatoria,
                  cor: AppColors.destaqueEquivalencia,
                ),
                const SizedBox(height: 14),
                _BarraNatureza(
                  label: 'Optativa',
                  natureza: progresso.optativa,
                  cor: AppColors.destaqueOptativa,
                ),
                if (progresso.temComplementar) ...[
                  const SizedBox(height: 14),
                  _BarraNatureza(
                    label: 'Complementar',
                    natureza: progresso.complementar,
                    cor: AppColors.destaqueModuloLivre,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CardIndicador(
                titulo: 'IRA',
                valor: iraTexto,
                icone: Icons.speed_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CardIndicador(
                titulo: 'Semestre atual',
                valor: (dados?.semestreAtual ?? 0) > 0
                    ? '${dados!.semestreAtual}º'
                    : '—',
                icone: Icons.calendar_today_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CardMaterias(contagem: progresso.contagem),
      ],
    );
  }

  static String _formatarIra(DadosFluxogramaUser? dados) {
    if (dados == null) return '—';
    final texto = dados.iraTexto;
    if (texto != null && texto.isNotEmpty) return texto;
    if (dados.ira <= 0) return '—';
    return dados.ira.toStringAsFixed(4).replaceAll('.', ',');
  }
}

/// Barra de progresso de uma natureza, com "1.230/2.400h" e horas faltantes.
class _BarraNatureza extends StatelessWidget {
  final String label;
  final ProgressoNatureza natureza;
  final Color cor;

  const _BarraNatureza({
    required this.label,
    required this.natureza,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final temExigencia = natureza.temExigencia;
    final horas = temExigencia
        ? '${formatarHorasPtBr(natureza.realizado)}/'
              '${formatarHorasPtBr(natureza.exigido!)}h'
        : '${formatarHorasPtBr(natureza.realizado)}h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tema.labelLarge),
            Text(
              horas,
              style: tema.labelMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: natureza.percentual / 100,
            minHeight: 8,
            color: cor,
            backgroundColor: AppColors.secondary,
          ),
        ),
        if (temExigencia) ...[
          const SizedBox(height: 4),
          Text(
            natureza.faltam > 0
                ? '${natureza.percentual.toStringAsFixed(0)}% • faltam '
                      '${formatarHorasPtBr(natureza.faltam)}h'
                : 'Concluído!',
            style: tema.bodySmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

/// Card pequeno de indicador (IRA, semestre atual).
class _CardIndicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _CardIndicador({
    required this.titulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    titulo,
                    style: tema.labelMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(valor, style: tema.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Card com as contagens de matérias por status.
class _CardMaterias extends StatelessWidget {
  final ContagemMaterias contagem;

  const _CardMaterias({required this.contagem});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matérias', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _ContadorMateria(
                  valor: contagem.concluidas,
                  label: 'Concluídas',
                  cor: AppColors.materiaCompleted,
                ),
                _ContadorMateria(
                  valor: contagem.emCurso,
                  label: 'Em curso',
                  cor: AppColors.materiaInProgress,
                ),
                _ContadorMateria(
                  valor: contagem.pendentes,
                  label: 'Pendentes',
                  cor: AppColors.materiaAvailable,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContadorMateria extends StatelessWidget {
  final int valor;
  final String label;
  final Color cor;

  const _ContadorMateria({
    required this.valor,
    required this.label,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Text('$valor', style: tema.titleMedium),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: tema.bodySmall?.copyWith(color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Rota (do app) da importação de histórico.
const String _kRotaImportarHistorico = '/importar-historico';

/// Upload pelo site — alternativa sempre oferecida no [CardHistorico].
/// Domínio vem do [AppConfig] (o antigo `no-fluxo.com` não existe).
final Uri _kUrlUploadSite = Uri.parse('${AppConfig.siteUrl}/upload-historico');

/// Card de estado do histórico do aluno:
/// - sem dados → CTA de importação (desbloqueia fluxograma/progresso/grade);
/// - dados de schema antigo ([DadosFluxogramaUser.schemaVersion] <
///   [kFluxogramaSchemaVersion]) → aviso pedindo reenvio;
/// - dados atualizados → confirmação com reenvio discreto.
///
/// Em todos os estados há o link secundário para o upload pelo site.
class CardHistorico extends StatelessWidget {
  final DadosFluxogramaUser? dados;

  const CardHistorico({super.key, this.dados});

  /// Abre o upload do site no navegador. Erros são silenciosos (o card
  /// continua oferecendo o fluxo nativo).
  static Future<void> _abrirSite() async {
    try {
      await launchUrl(_kUrlUploadSite, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Não foi possível abrir o site de upload: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final d = dados;
    final desatualizado =
        d != null && (d.schemaVersion ?? 1) < kFluxogramaSchemaVersion;

    final IconData icone;
    final Color corIcone;
    final String texto;
    final Widget botao;
    if (d == null) {
      icone = Icons.upload_file_outlined;
      corIcone = AppColors.accent;
      texto =
          'Importe seu histórico para desbloquear fluxograma, progresso '
          'e grade';
      botao = ElevatedButton.icon(
        onPressed: () => context.go(_kRotaImportarHistorico),
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: const Text('Importar histórico'),
      );
    } else if (desatualizado) {
      icone = Icons.warning_amber_rounded;
      corIcone = Colors.amber;
      texto =
          'Seu histórico foi importado numa versão antiga — reenvie para '
          'ver equivalências e módulo livre';
      botao = OutlinedButton.icon(
        onPressed: () => context.go(_kRotaImportarHistorico),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Reenviar histórico'),
      );
    } else {
      icone = Icons.check_circle_outline;
      corIcone = AppColors.materiaCompleted;
      texto = 'Histórico importado';
      botao = TextButton(
        onPressed: () => context.go(_kRotaImportarHistorico),
        child: const Text('Reenviar histórico'),
      );
    }

    return Card(
      shape: desatualizado
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.45)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 2),
                Icon(icone, size: 20, color: corIcone),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.foreground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            botao,
            const SizedBox(height: 2),
            TextButton(
              onPressed: _abrirSite,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                textStyle: tema.bodySmall,
              ),
              child: Text('ou use o site ${AppConfig.siteHost}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card genérico de mensagem informativa.
class _CardMensagem extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _CardMensagem({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(width: 2),
            Icon(icone, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seção de conta: suporte, novidades e sair. Só aparece para usuário logado
/// (a view de visitante não a renderiza).
class _SecaoConta extends ConsumerWidget {
  const _SecaoConta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.support_agent_outlined,
                  color: AppColors.accent,
                ),
                title: const Text('Suporte e feedback'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SuporteScreen()),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.accent,
                ),
                title: const Text('Novidades'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                // Reabre o dialog manualmente (fora da regra do "1x por
                // release").
                onTap: () => mostrarNovidades(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          // O unregister do push acontece dentro do logout (core).
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(
            Icons.logout,
            size: 18,
            color: AppColors.destructive,
          ),
          label: const Text(
            'Sair da conta',
            style: TextStyle(color: AppColors.destructive),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppColors.destructive.withValues(alpha: 0.45),
            ),
          ),
          // Sucesso: o redirect do router leva para /login.
        ),
      ],
    );
  }
}

/// Rodapé discreto da tela.
class _Rodape extends StatelessWidget {
  const _Rodape();

  @override
  Widget build(BuildContext context) {
    return Text(
      'NoFluxoUNB • dados do SIGAA via importação de histórico',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
    );
  }
}

// ─── Visitante ───────────────────────────────────────────────────────────────

/// Tela para visitante (modo anônimo): convite para entrar.
class PerfilVisitanteView extends ConsumerWidget {
  const PerfilVisitanteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.secondary,
            child: Icon(
              Icons.person_outline,
              size: 36,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Você está no modo visitante',
            style: tema.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Entre na sua conta para ver seu progresso no curso, IRA, '
            'carga horária e suas matérias.',
            style: tema.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            // Sair do modo visitante: o redirect do router leva para /login.
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Entrar ou criar conta'),
          ),
          const Spacer(),
          const _Rodape(),
        ],
      ),
    );
  }
}
