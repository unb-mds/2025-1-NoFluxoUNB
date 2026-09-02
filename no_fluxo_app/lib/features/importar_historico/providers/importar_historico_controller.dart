import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
import '../../../core/pdf/historico_pdf_parser.dart';
import '../../../core/pdf/modelos_extracao.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/json_utils.dart';
import '../data/importar_historico_repository.dart';
import '../domain/casamento.dart';
import '../domain/montagem_fluxograma.dart';

/// Flag de sessão: o usuário tocou em "Agora não" no onboarding. O redirect
/// pós-login respeita; o logout limpa (ver router.dart).
final adiouImportacaoProvider = StateProvider<bool>((ref) => false);

/// Etapas da importação — a máquina de estados do `uploadStore` do site.
enum EtapaImportacao { inicial, extraindo, casando, sucesso, erro }

/// Estado da tela de importação.
class ImportarHistoricoState {
  final EtapaImportacao etapa;
  final int progresso;
  final String nomeArquivo;
  final String? erro;
  final ParsedPdfResult? extraido;
  final CasarDisciplinasResultado? resultado;

  /// Não-nulo = modal de seleção de curso aberto.
  final SelecaoDeCurso? selecaoDeCurso;
  final bool salvando;

  const ImportarHistoricoState({
    this.etapa = EtapaImportacao.inicial,
    this.progresso = 0,
    this.nomeArquivo = '',
    this.erro,
    this.extraido,
    this.resultado,
    this.selecaoDeCurso,
    this.salvando = false,
  });

  static const Object _mantem = Object();

  ImportarHistoricoState copyWith({
    EtapaImportacao? etapa,
    int? progresso,
    String? nomeArquivo,
    Object? erro = _mantem,
    Object? extraido = _mantem,
    Object? resultado = _mantem,
    Object? selecaoDeCurso = _mantem,
    bool? salvando,
  }) {
    return ImportarHistoricoState(
      etapa: etapa ?? this.etapa,
      progresso: progresso ?? this.progresso,
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      erro: identical(erro, _mantem) ? this.erro : erro as String?,
      extraido: identical(extraido, _mantem)
          ? this.extraido
          : extraido as ParsedPdfResult?,
      resultado: identical(resultado, _mantem)
          ? this.resultado
          : resultado as CasarDisciplinasResultado?,
      selecaoDeCurso: identical(selecaoDeCurso, _mantem)
          ? this.selecaoDeCurso
          : selecaoDeCurso as SelecaoDeCurso?,
      salvando: salvando ?? this.salvando,
    );
  }
}

/// Máquina de estados da importação — porte do `uploadStore` do site
/// (uploadFile / retryWithSelectedCourse / saveAndNavigate / startManualMode /
/// dismissCourseSelection / reset), com o parse feito pelo
/// [historicoPdfParserProvider] (contrato; a implementação real pode chegar
/// depois) e o casamento pela RPC via repositório.
class ImportarHistoricoController extends Notifier<ImportarHistoricoState> {
  Timer? _timerProgresso;

  @override
  ImportarHistoricoState build() {
    ref.onDispose(_pararSimulacao);
    return const ImportarHistoricoState();
  }

  ImportarHistoricoRepository get _repo =>
      ref.read(importarHistoricoRepositoryProvider);

  // ── Simulação de progresso (timer de 100ms, como no site) ─────────────────

  void _simularProgresso(int de, int ate, Duration duracao) {
    _pararSimulacao();
    final passos = duracao.inMilliseconds ~/ 100;
    if (passos <= 0) {
      state = state.copyWith(progresso: ate);
      return;
    }
    final incremento = (ate - de) / passos;
    var atual = de.toDouble();
    _timerProgresso = Timer.periodic(const Duration(milliseconds: 100), (_) {
      atual = math.min(atual + incremento, ate.toDouble());
      state = state.copyWith(progresso: atual.round());
      if (atual >= ate) _pararSimulacao();
    });
  }

  void _pararSimulacao() {
    _timerProgresso?.cancel();
    _timerProgresso = null;
  }

  // ── Fluxo principal (uploadFile do site) ──────────────────────────────────

  /// Processa o PDF: parse local (0→45%) + casamento na RPC (50→85%).
  Future<void> processarArquivo(String nome, Uint8List bytes) async {
    state = ImportarHistoricoState(
      etapa: EtapaImportacao.extraindo,
      nomeArquivo: nome,
    );
    try {
      _simularProgresso(0, 45, const Duration(seconds: 3));
      final extraido = await ref
          .read(historicoPdfParserProvider)
          .parse(bytes, nome);
      _pararSimulacao();
      state = state.copyWith(
        progresso: 50,
        extraido: extraido,
        etapa: EtapaImportacao.casando,
      );

      _simularProgresso(50, 85, const Duration(seconds: 4));
      final resposta = await _repo.casarDisciplinas(extraido.toPDados());
      _pararSimulacao();
      _tratarResposta(resposta);
    } catch (e) {
      _falhar(e, 'Erro desconhecido ao processar o PDF.');
    }
  }

  /// Reenvia o MESMO p_dados com o curso escolhido — porte de
  /// `retryWithSelectedCourse`. Pode voltar COURSE_SELECTION de novo
  /// (o modal reabre).
  Future<void> confirmarCursoSelecionado(OpcaoCurso opcao) async {
    final extraido = state.extraido;
    if (extraido == null) {
      state = state.copyWith(
        etapa: EtapaImportacao.erro,
        selecaoDeCurso: null,
        erro: 'Dados do PDF não encontrados. Tente novamente.',
      );
      return;
    }
    state = state.copyWith(
      selecaoDeCurso: null,
      etapa: EtapaImportacao.casando,
      progresso: 55,
      erro: null,
    );
    try {
      _simularProgresso(55, 85, const Duration(seconds: 3));
      final resposta = await _repo.casarDisciplinas(
        extraido.toPDados(
          cursoSelecionado: opcao.nomeCurso,
          idCursoSelecionado: opcao.idCurso,
        ),
      );
      _pararSimulacao();
      _tratarResposta(resposta);
    } catch (e) {
      _falhar(e, 'Erro ao processar disciplinas.');
    }
  }

  /// Cancelou o modal de seleção — mesmo texto do site.
  void cancelarSelecaoDeCurso() {
    state = state.copyWith(
      selecaoDeCurso: null,
      etapa: EtapaImportacao.erro,
      erro: 'Seleção de curso cancelada. Tente novamente.',
    );
  }

  void _tratarResposta(RespostaCasamento resposta) {
    switch (resposta) {
      case CasamentoPrecisaDeCurso(:final selecao):
        state = state.copyWith(
          progresso: 60,
          etapa: EtapaImportacao.casando,
          selecaoDeCurso: selecao,
        );
      case CasamentoConcluido(:final resultado):
        state = state.copyWith(
          progresso: 100,
          etapa: EtapaImportacao.sucesso,
          resultado: resultado,
        );
    }
  }

  void _falhar(Object e, String mensagemPadrao) {
    _pararSimulacao();
    final mensagem = e is ImportarHistoricoException
        ? e.message
        : e is PdfSemTextoException
        ? e.message
        : mensagemPadrao;
    state = state.copyWith(etapa: EtapaImportacao.erro, erro: mensagem);
  }

  // ── Salvar e navegar (saveAndNavigate do site) ────────────────────────────

  /// Monta o [DadosFluxogramaUser], salva e recarrega o perfil no auth.
  /// Retorna null em sucesso ou a mensagem de erro para a UI.
  Future<String?> salvarFluxograma() async {
    final resultado = state.resultado;
    final extraido = state.extraido;
    final user = ref.read(authProvider).valueOrNull?.user;
    if (resultado == null || user == null) {
      return 'Dados insuficientes para salvar.';
    }

    state = state.copyWith(salvando: true);
    try {
      final meta = MetaHistorico(
        nomeCurso: extraido?.cursoExtraido ?? '',
        matricula: extraido?.matricula ?? '',
        anoAtual: extraido?.semestreAtual ?? '',
        matrizCurricular: extraido?.matrizCurricular ?? '',
        semestreAtual: extraido?.numeroSemestre ?? 0,
        suspensoes: extraido?.suspensoes ?? const [],
      );
      final iraExtraido = extraido?.extractedData
          .where((d) => d.tipoDado == 'IRA')
          .firstOrNull;

      final dados = montarDadosFluxogramaUser(
        resultado: resultado,
        meta: meta,
        iraTexto: iraExtraido?.iraValorTexto,
      );
      final equivalenciasPdf = injetarEquivalenciasDoPdf(
        dados,
        extraido?.equivalenciasPdf ?? const [],
      );
      // Carimba a versão do schema (quem precisa reenviar para recursos
      // novos é detectado por isso).
      dados.schemaVersion = kFluxogramaSchemaVersion;

      await _repo.salvarFluxograma(
        idUser: user.idUser,
        fluxogramaJson: dadosFluxogramaUserParaJson(
          dados,
          equivalenciasPdf: equivalenciasPdf,
        ),
        semestreAtual: meta.semestreAtual == 0 ? null : meta.semestreAtual,
        cargaHorariaIntegralizada: extraido?.cargaHorariaIntegralizada
            ?.toJson(),
        metadados: MetadadosEnvioHistorico(
          cursoExtraido: extraido?.cursoExtraido,
          matrizCurricular: extraido?.matrizCurricular,
          matricula: extraido?.matricula,
          ira: iraExtraido?.iraValor,
          mediaPonderada: extraido?.mediaPonderada,
          cargaHorariaIntegralizada: extraido?.cargaHorariaIntegralizada
              ?.toJson(),
          suspensoes: extraido?.suspensoes,
          resumo: resultado.resumo,
        ),
      );

      // O app inteiro passa a ver o fluxograma novo.
      await ref.read(authProvider.notifier).recarregarPerfil();
      return null;
    } catch (e) {
      final mensagem = e is ImportarHistoricoException
          ? e.message
          : 'Erro ao salvar fluxograma.';
      return mensagem;
    } finally {
      state = state.copyWith(salvando: false);
    }
  }

  // ── Modo manual (startManualMode do site) ─────────────────────────────────

  /// Salva um fluxograma zerado para preenchimento manual. Retorna null em
  /// sucesso ou a mensagem de erro.
  Future<String?> iniciarModoManual(OpcaoCurso opcao) async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) return 'Você precisa estar logado.';

    final dados = DadosFluxogramaUser(
      nomeCurso: opcao.nomeCurso,
      ira: 0,
      matricula: 'Manual',
      horasIntegralizadas: 0,
      suspensoes: const [],
      anoAtual: '${DateTime.now().year}.1',
      matrizCurricular: opcao.matrizCurricular ?? '',
      semestreAtual: 1,
      dadosFluxograma: [],
      schemaVersion: kFluxogramaSchemaVersion,
    );

    try {
      await _repo.salvarFluxograma(
        idUser: user.idUser,
        fluxogramaJson: dadosFluxogramaUserParaJson(dados),
        semestreAtual: 1,
        metadados: MetadadosEnvioHistorico(
          cursoExtraido: opcao.nomeCurso,
          matrizCurricular: opcao.matrizCurricular ?? '',
          matricula: 'Manual',
          ira: 0,
          mediaPonderada: 0,
          suspensoes: const [],
        ),
      );
      await ref.read(authProvider.notifier).recarregarPerfil();
      return null;
    } catch (_) {
      return 'Erro ao iniciar preenchimento manual.';
    }
  }

  /// Volta ao estado inicial ("Enviar outro PDF" / "Tentar novamente").
  void reset() {
    _pararSimulacao();
    state = const ImportarHistoricoState();
  }
}

/// Estado global da importação de histórico.
final importarHistoricoControllerProvider =
    NotifierProvider<ImportarHistoricoController, ImportarHistoricoState>(
      ImportarHistoricoController.new,
    );

/// Total de optativas exibido no card de sucesso — mesma regra da tela do
/// site (ProcessingResults): só concluídas + em andamento (MATR).
int contarOptativasExibidas(CasarDisciplinasResultado resultado) {
  bool concluida(Map<String, dynamic> m) {
    final status = parseStringOr(m['status']).trim().toUpperCase();
    final fluxo = parseStringOr(m['status_fluxograma']).trim().toLowerCase();
    return fluxo == 'concluida' ||
        fluxo == 'concluida_equivalencia' ||
        status == 'APR' ||
        status == 'CUMP' ||
        status == 'DISP';
  }

  bool emAndamento(Map<String, dynamic> m) {
    final status = parseStringOr(m['status']).trim().toUpperCase();
    final fluxo = parseStringOr(m['status_fluxograma']).trim().toLowerCase();
    return fluxo == 'em_andamento' || status == 'MATR';
  }

  return resultado.materiasOptativas
      .where((m) => concluida(m) || emAndamento(m))
      .length;
}
