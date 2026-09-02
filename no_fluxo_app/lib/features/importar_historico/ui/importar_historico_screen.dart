import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/importar_historico_repository.dart';
import '../data/selecionador_arquivo.dart';
import '../domain/casamento.dart';
import '../domain/validacao_arquivo.dart';
import '../providers/importar_historico_controller.dart';
import 'widgets/ajuda_historico_sheet.dart';
import 'widgets/painel_selecao_curso.dart';
import 'widgets/resultado_sucesso_view.dart';

/// Tela "Importar histórico" — onboarding pós-login (e reenvio) do app,
/// porte da /upload-historico do site. Fora do shell de abas.
class ImportarHistoricoScreen extends ConsumerWidget {
  const ImportarHistoricoScreen({super.key});

  void _mostrarMensagem(
    BuildContext context,
    String mensagem, {
    bool erro = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro
            ? AppColors.destructive.withValues(alpha: 0.9)
            : AppColors.materiaCompleted,
      ),
    );
  }

  Future<void> _selecionarArquivo(BuildContext context, WidgetRef ref) async {
    final arquivo = await ref
        .read(selecionadorDeArquivoProvider)
        .selecionarPdf();
    if (arquivo == null || !context.mounted) return;

    final bytes = arquivo.bytes;
    final erro = validarArquivoPdf(
      nome: arquivo.nome,
      tamanhoBytes: bytes?.length ?? arquivo.tamanhoBytes,
    );
    if (erro != null) {
      _mostrarMensagem(context, erro);
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      _mostrarMensagem(context, 'O arquivo está vazio.');
      return;
    }
    await ref
        .read(importarHistoricoControllerProvider.notifier)
        .processarArquivo(arquivo.nome, bytes);
  }

  Future<void> _salvarEVisualizar(BuildContext context, WidgetRef ref) async {
    final erro = await ref
        .read(importarHistoricoControllerProvider.notifier)
        .salvarFluxograma();
    if (!context.mounted) return;
    if (erro != null) {
      _mostrarMensagem(context, erro);
      return;
    }
    _mostrarMensagem(context, 'Fluxograma salvo com sucesso!', erro: false);
    context.go('/fluxograma');
  }

  Future<void> _abrirModoManual(BuildContext context, WidgetRef ref) async {
    final List<OpcaoCurso> opcoes;
    try {
      opcoes = await ref
          .read(importarHistoricoRepositoryProvider)
          .buscarOpcoesDeCurso();
    } catch (_) {
      if (context.mounted) {
        _mostrarMensagem(context, 'Não foi possível carregar os cursos.');
      }
      return;
    }
    if (!context.mounted) return;

    final escolhido = await showModalBottomSheet<OpcaoCurso>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: PainelSelecaoCurso(
            mensagem:
                'Neste modo, você preencherá as disciplinas aprovadas '
                'clicando nelas no fluxograma. Para começar, selecione '
                'seu curso:',
            cursos: opcoes,
            onConfirmar: (opcao) => Navigator.of(sheetContext).pop(opcao),
            onCancelar: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );
    if (escolhido == null || !context.mounted) return;

    final erro = await ref
        .read(importarHistoricoControllerProvider.notifier)
        .iniciarModoManual(escolhido);
    if (!context.mounted) return;
    if (erro != null) {
      _mostrarMensagem(context, erro);
      return;
    }
    _mostrarMensagem(
      context,
      'Modo manual iniciado! Você pode alterar o status das matérias '
      'clicando nelas.',
      erro: false,
    );
    context.go('/fluxograma');
  }

  void _adiarImportacao(BuildContext context, WidgetRef ref) {
    ref.read(adiouImportacaoProvider.notifier).state = true;
    context.go('/fluxograma');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(importarHistoricoControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    // "Agora não" só faz sentido no onboarding (perfil sem fluxograma).
    final auth = ref.watch(authProvider).valueOrNull;
    final veioDoOnboarding = auth?.user != null && auth?.dados == null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Importar histórico',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Envie o PDF do seu histórico oficial da UnB. Os dados '
                    'são usados só para montar seu fluxograma nesta '
                    'plataforma.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._conteudo(context, ref, estado),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => mostrarAjudaHistorico(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Como obter seu histórico acadêmico?'),
                    ),
                  ),
                  if (estado.nomeArquivo.isNotEmpty &&
                      estado.etapa != EtapaImportacao.inicial)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Arquivo selecionado: ${estado.nomeArquivo}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  if (veioDoOnboarding &&
                      estado.etapa == EtapaImportacao.inicial)
                    Center(
                      child: TextButton(
                        onPressed: () => _adiarImportacao(context, ref),
                        child: Text(
                          'Agora não',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(
    BuildContext context,
    WidgetRef ref,
    ImportarHistoricoState estado,
  ) {
    final selecao = estado.selecaoDeCurso;
    if (selecao != null) {
      final notifier = ref.read(importarHistoricoControllerProvider.notifier);
      return [
        _Cartao(
          child: PainelSelecaoCurso(
            mensagem: selecao.mensagem,
            cursos: selecao.cursos,
            onConfirmar: notifier.confirmarCursoSelecionado,
            onCancelar: notifier.cancelarSelecaoDeCurso,
          ),
        ),
      ];
    }

    switch (estado.etapa) {
      case EtapaImportacao.inicial:
        return [
          OutlinedButton(
            onPressed: () => _abrirModoManual(context, ref),
            child: const Text('Preencha manualmente'),
          ),
          const SizedBox(height: 16),
          _Cartao(
            child: _AreaDeEnvio(
              onSelecionar: () => _selecionarArquivo(context, ref),
            ),
          ),
        ];

      case EtapaImportacao.extraindo:
      case EtapaImportacao.casando:
        return [
          _Cartao(
            child: _ProgressoView(
              progresso: estado.progresso,
              extraindo: estado.etapa == EtapaImportacao.extraindo,
            ),
          ),
        ];

      case EtapaImportacao.sucesso:
        final resultado = estado.resultado;
        if (resultado == null) return const [];
        return [
          _Cartao(
            child: ResultadoSucessoView(
              resultado: resultado,
              salvando: estado.salvando,
              onVisualizarFluxograma: () => _salvarEVisualizar(context, ref),
              onEnviarOutro: () => ref
                  .read(importarHistoricoControllerProvider.notifier)
                  .reset(),
            ),
          ),
        ];

      case EtapaImportacao.erro:
        return [
          _Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: AppColors.destructive,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não foi possível processar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  estado.erro ??
                      'Ocorreu um erro inesperado. Verifique o arquivo e '
                          'tente novamente.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(importarHistoricoControllerProvider.notifier)
                      .reset(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ];
    }
  }
}

/// Card padrão da tela (o "upload-shell" do site).
class _Cartao extends StatelessWidget {
  final Widget child;

  const _Cartao({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Estado inicial: área de envio com o botão "Selecionar arquivo".
class _AreaDeEnvio extends StatelessWidget {
  final VoidCallback onSelecionar;

  const _AreaDeEnvio({required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.upload_file, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Envie seu histórico em PDF',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onSelecionar,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Selecionar arquivo'),
        ),
        const SizedBox(height: 12),
        Text(
          'Somente PDF (máx. 10MB). O documento deve ser o histórico '
          'oficial da UnB.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Progresso com porcentagem simulada (UploadProgress do site).
class _ProgressoView extends StatelessWidget {
  final int progresso;
  final bool extraindo;

  const _ProgressoView({required this.progresso, required this.extraindo});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 16),
        Text(
          extraindo ? 'Enviando seu histórico…' : 'Processando disciplinas…',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Isso pode levar alguns segundos.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progresso / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$progresso%',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
