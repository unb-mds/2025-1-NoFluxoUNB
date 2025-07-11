import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:mobile_app/config/size_config.dart';
import 'package:mobile_app/environment.dart';
import 'package:mobile_app/screens/upload-historico/services/upload_historico_service.dart';
import '../../../cache/shared_preferences_helper.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_navbar.dart';
import '../../../widgets/animated_background.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:dotted_border/dotted_border.dart';
import 'dart:convert';

var log = Logger("UploadHistoricoScreen");

enum UploadState { initial, uploading, success }

class UploadHistoricoScreen extends StatefulWidget {
  const UploadHistoricoScreen({Key? key}) : super(key: key);

  @override
  State<UploadHistoricoScreen> createState() => _UploadHistoricoScreenState();
}

class _UploadHistoricoScreenState extends State<UploadHistoricoScreen>
    with TickerProviderStateMixin {
  String? _fileName;
  bool _isHovering = false;
  bool _isCloseIconHovering = false;
  UploadState _uploadState = UploadState.initial;
  double _progress = 0.0;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late AnimationController _hoverController;
  late AnimationController _pulseController;
  late AnimationController _progressGradientController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _hoverAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressGradientAnimation;
  Map<String, dynamic>? _dadosExtraidos;
  List<Map<String, dynamic>>? _disciplinasCasadas;
  Map<String, dynamic>? _dadosValidacao;
  List<Map<String, dynamic>>? _materiasOptativas;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _progressGradientController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _progressGradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _progressGradientController, curve: Curves.linear),
    );

    // Iniciar animações contínuas
    _pulseController.repeat(reverse: true);
    _progressGradientController.repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    _hoverController.dispose();
    _pulseController.dispose();
    _progressGradientController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    setState(() {
      _isHovering = isHovering;
    });
    if (isHovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  void _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileName = result.files.single.name;
        });

        final uploadResult = await UploadHistoricoService.uploadPdfBytes(
            result.files.single.bytes!, result.files.single.name);

        uploadResult.fold(
          (error) {
            // Handle error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao processar PDF: $error'),
                backgroundColor: Colors.red,
              ),
            );
            _resetUpload();
          },
          (dados) async {
            setState(() {
              _dadosExtraidos = dados;
            });
            await _casarDisciplinasComBanco();
            await _simulateUpload();
          },
        );
      }
    } catch (e) {
      debugPrint('Erro ao selecionar o arquivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar arquivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _resetUpload();
    }
  }

  Future<void> _simulateUpload() async {
    setState(() {
      _uploadState = UploadState.uploading;
      _progress = 0.0;
    });

    // Simula o progresso do upload
    for (int i = 0; i <= 100; i += (5 + (DateTime.now().millisecond % 10))) {
      if (mounted) {
        setState(() {
          _progress = i.toDouble();
        });
        await Future.delayed(
            Duration(milliseconds: 200 + (DateTime.now().millisecond % 300)));
      }
    }

    if (mounted) {
      setState(() {
        _progress = 100.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _uploadState = UploadState.success;
        });
        _fadeController.forward();
      }
    }
  }

  void _resetUpload() {
    setState(() {
      _uploadState = UploadState.initial;
      _fileName = null;
      _progress = 0.0;
    });
    _fadeController.reset();
  }

  Future<void> _continueToFlowchart() async {
    // upload fluxograma para o banco de dados

    try {
      final user = SharedPreferencesHelper.currentUser;

      if (user == null) {
        return;
      }

      DadosFluxogramaUser dadosFluxograma = DadosFluxogramaUser(
          nomeCurso: "",
          ira: 0,
          dadosFluxograma: [],
          matricula: "",
          semestreAtual: 0,
          matrizCurricular: "");

      dadosFluxograma.nomeCurso = _dadosValidacao!['curso_extraido'];

      dadosFluxograma.matricula = _dadosExtraidos!["matricula"];

      dadosFluxograma.matrizCurricular = _dadosExtraidos!["matriz_curricular"];

      dadosFluxograma.ira = _dadosExtraidos!["media_ponderada"];

      dadosFluxograma.semestreAtual = _dadosExtraidos!["numero_semestre"];

      dadosFluxograma.dadosFluxograma = List.generate(20, (index) => []);

      for (var materiaCasada in _disciplinasCasadas!) {
        var nivel = materiaCasada["nivel"];

        nivel ??= 0;

        dadosFluxograma.dadosFluxograma[nivel]
            .add(DadosMateria.fromJson(materiaCasada));
      }

      final uploadResult =
          await UploadHistoricoService.uploadFluxogramaToDB(dadosFluxograma);
      uploadResult.fold(
        (error) {
          log.severe('Erro ao salvar fluxograma: $error');
        },
        (message) {
          log.info('Fluxograma salvo com sucesso: $message');

          context.go('/meu-fluxograma');
        },
      );
    } catch (e, st) {
      log.severe(e, st);
    }
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header com título e botão de fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Como obter seu histórico acadêmico',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.grey[500], size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 22,
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Passo 1
                    const _PassoHistorico(
                      titulo: '1º PASSO - Acesse o SIGAA',
                      descricao: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Entre no '),
                            TextSpan(
                              text: 'SIGAA',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                                text: ' com seu login e senha institucional.'),
                          ],
                          style:
                              TextStyle(color: Color(0xFF1A202C), fontSize: 16),
                        ),
                      ),
                      imagem: 'assets/help/tela_de_cadastro.png',
                      alt: 'Tela de login do SIGAA',
                    ),
                    // Passo 2
                    const _PassoHistorico(
                      titulo: '2º PASSO - Selecione "Emitir Histórico"',
                      descricao: Text(
                        'No menu lateral, clique em Ensino e depois em Emitir Histórico.',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                      ),
                      imagem: 'assets/help/emitir_historico.png',
                      alt: 'Menu Emitir Histórico no SIGAA',
                    ),
                    // Passo 3
                    const _PassoHistorico(
                      titulo:
                          '3º PASSO - Faça o upload do PDF para o NoFluxoUNB',
                      descricao: Text(
                        'Salve o arquivo PDF gerado em seu computador e faça o upload nesta página.',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                      ),
                      imagem: 'assets/help/historico_baixado.png',
                      alt: 'Exemplo de histórico acadêmico gerado',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B469B),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendi',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fundo animado com círculos coloridos borrados
          const AnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const AppNavbar(),
                  SizedBox(height: 32),
                  Center(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 300),
                      child: _buildUploadContainer(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_uploadState == UploadState.initial)
                    Center(
                      child: _buildHelpButton(),
                    ),
                  SizedBox(height: 32),
                  if (_disciplinasCasadas != null) ...[
                    const SizedBox(height: 24),
                    _buildResultadoProcessamento(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = 350;
        EdgeInsets padding =
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        double fontSize = 16;
        if (constraints.maxWidth < 500) {
          maxWidth = constraints.maxWidth * 0.95;
          padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
          fontSize = 14;
        }
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FF2), Color(0xFFF357A8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2FF2).withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showHelpModal,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.help_outline,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Como obter seu histórico acadêmico?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUploadContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = 600;
        double horizontalPadding = 32;
        if (constraints.maxWidth < 700) {
          maxWidth = constraints.maxWidth * 0.95;
          horizontalPadding = 16;
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -5 * _hoverAnimation.value),
                  child: DottedBorder(
                    options: const RoundedRectDottedBorderOptions(
                      color: Colors.white,
                      strokeWidth: 2,
                      radius: Radius.circular(16),
                      dashPattern: [8, 6],
                      padding: EdgeInsets.zero,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(horizontalPadding),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15 + (0.1 * _hoverAnimation.value)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildUploadContent(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadContent() {
    switch (_uploadState) {
      case UploadState.initial:
        return _buildInitialState();
      case UploadState.uploading:
        return _buildUploadingState();
      case UploadState.success:
        return _buildSuccessState();
    }
  }

  Widget _buildInitialState() {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: _pickFile,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de Upload com animação de pulso
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Texto principal
            const Text(
              'Arraste seu histórico acadêmico aqui',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Texto "ou"
            const Text(
              'ou',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Botão de seleção com animação hover
            _buildUploadButton(),
            const SizedBox(height: 16),

            // Formatos aceitos
            const Text(
              'Somente arquivos PDF são aceitos',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -2 * _hoverAnimation.value),
            child: SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text(
                  'Selecionar Histórico',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.lerp(
                    const Color(0xFF007BFF),
                    const Color(0xFF0056b3),
                    _hoverAnimation.value,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4 + (2 * _hoverAnimation.value),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título
        const Text(
          'Processando seu histórico...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Barra de progresso com animação de gradiente
        Container(
          width: double.infinity,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Barra de progresso base
                LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF007BFF),
                  ),
                ),
                // Gradiente animado sobre a barra de progresso
                AnimatedBuilder(
                  animation: _progressGradientAnimation,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const [
                              Color(0xFF007BFF),
                              Color(0xFF00C6FF),
                              Color(0xFF7B2FF2),
                            ],
                            stops: [
                              _progressGradientAnimation.value - 0.5,
                              _progressGradientAnimation.value,
                              _progressGradientAnimation.value + 0.5,
                            ].map((e) => e.clamp(0.0, 1.0)).toList(),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress / 100,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Texto de progresso
        Text(
          '${_progress.toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card de sucesso com borda pontilhada branca
          DottedBorder(
            options: const RoundedRectDottedBorderOptions(
              color: Colors.white,
              strokeWidth: 2,
              radius: Radius.circular(20),
              dashPattern: [8, 6],
              padding: EdgeInsets.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone de sucesso com círculo verde
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.greenAccent,
                          width: 4,
                          style: BorderStyle.solid,
                          strokeAlign: BorderSide.strokeAlignOutside),
                      color: Colors.transparent,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.greenAccent,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Título
                  const Text(
                    'Histórico processado com sucesso!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Subtítulo
                  const Text(
                    'Seu fluxograma personalizado está sendo gerado.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // Botão azul destacado com animação hover
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Exibição do arquivo selecionado com animação hover
          if (_fileName != null) _buildFileItem(),
        ],
      ),
    );
  }

  Widget _buildFileItem() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = 15;
        double iconSize = 22;
        EdgeInsets contentPadding =
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
        if (constraints.maxWidth < 400) {
          fontSize = 13;
          iconSize = 18;
          contentPadding =
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arquivo selecionado:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: contentPadding,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.insert_drive_file_rounded,
                        color: Colors.white, size: iconSize),
                  ),
                  Expanded(
                    child: Text(
                      _fileName!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isCloseIconHovering = true),
                    onExit: (_) => setState(() => _isCloseIconHovering = false),
                    child: AnimatedBuilder(
                      animation: _hoverAnimation,
                      builder: (context, child) {
                        return IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: _isCloseIconHovering
                                ? Colors.redAccent
                                : Colors.white,
                            size: iconSize,
                          ),
                          onPressed: _resetUpload,
                          tooltip: 'Remover arquivo',
                          splashRadius: iconSize + 4,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContinueButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: AnimatedBuilder(
            animation: _hoverAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -2 * _hoverAnimation.value),
                child: SizedBox(
                  child: ElevatedButton.icon(
                    onPressed: _continueToFlowchart,
                    label: const Text(
                      'Continuar para o Fluxograma',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.lerp(
                        const Color(0xFF007BFF),
                        const Color(0xFF0056b3),
                        _hoverAnimation.value,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4 + (2 * _hoverAnimation.value),
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _casarDisciplinasComBanco() async {
    if (_dadosExtraidos == null) return;

    try {
      final resultado =
          await UploadHistoricoService.casarDisciplinas(_dadosExtraidos!);

      resultado.fold(
        (error) {
          // Só mostra o diálogo de seleção de curso se for erro de seleção
          if (error.startsWith('SELECAO_CURSO:')) {
            final errorData = Map<String, dynamic>.from(
                jsonDecode(error.replaceFirst('SELECAO_CURSO:', '')));
            _mostrarDialogoSelecaoCurso(errorData);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (dados) {
          setState(() {
            _disciplinasCasadas =
                List<Map<String, dynamic>>.from(dados['disciplinas_casadas']);
            _dadosValidacao = dados['dados_validacao'] != null
                ? Map<String, dynamic>.from(dados['dados_validacao'])
                : null;
            _materiasOptativas = dados['materias_optativas'] != null
                ? List<Map<String, dynamic>>.from(dados['materias_optativas'])
                : null;
          });
        },
      );
    } catch (e, st) {
      log.severe(e, st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar disciplinas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDialogoSelecaoCurso(Map<String, dynamic> errorData) {
    final cursosList = (errorData['cursos_disponiveis'] is List)
        ? errorData['cursos_disponiveis']
        : (errorData['cursos_disponiveis'] != null
            ? [errorData['cursos_disponiveis']]
            : []);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecione seu curso'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorData['message'] ??
                      'Por favor, selecione o curso correto:',
                  style: const TextStyle(fontSize: 16),
                ),
                if (errorData['palavras_chave_encontradas'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Palavras-chave encontradas: ${(errorData['palavras_chave_encontradas'] as List).join(', ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cursosList.length,
                    itemBuilder: (context, index) {
                      final curso = cursosList[index];
                      return ListTile(
                        title: Text(curso['nome_curso'] ?? ''),
                        subtitle: curso['matriz_curricular'] != null
                            ? Text('Matriz: ${curso['matriz_curricular']}')
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          _selecionarCurso(curso);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetUpload();
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _selecionarCurso(Map<String, dynamic> cursoSelecionado) async {
    // Atualizar os dados extraídos com o curso selecionado
    if (_dadosExtraidos != null) {
      _dadosExtraidos!['curso_extraido'] = cursoSelecionado['nome_curso'];
      _dadosExtraidos!['matriz_curricular'] =
          cursoSelecionado['matriz_curricular'];

      // Tentar casar disciplinas novamente com o curso selecionado
      await _casarDisciplinasComBanco();
    }
  }

  Widget _buildResultadoProcessamento() {
    final disciplinasEncontradas = _disciplinasCasadas!
        .where((d) =>
            d['encontrada_no_banco'] == true ||
            d['encontrada_no_banco'] == 'true')
        .toList();

    final disciplinasNaoEncontradas = _disciplinasCasadas!
        .where((d) =>
            d['encontrada_no_banco'] == false ||
            d['encontrada_no_banco'] == 'false')
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Resultado do Processamento:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),

          // Resumo geral
          Text(
            '📋 Total de disciplinas processadas: ${_disciplinasCasadas!.length}',
            style: TextStyle(color: Colors.white),
          ),
          Text(
            '✅ Disciplinas encontradas no banco: ${disciplinasEncontradas.length}',
            style: TextStyle(color: Colors.green),
          ),
          Text(
            '❌ Disciplinas não encontradas: ${disciplinasNaoEncontradas.length}',
            style: TextStyle(color: Colors.orange),
          ),

          if (_materiasOptativas != null) ...[
            const SizedBox(height: 8),
            Text(
              '🎯 Matérias optativas: ${_materiasOptativas!.length}',
              style: TextStyle(color: Colors.purple),
            ),
          ],

          Text(
            '👨‍🏫 Disciplinas com professor: ${_disciplinasCasadas!.where((d) => d['professor'] != null && d['professor'].toString().isNotEmpty).length}',
            style: TextStyle(color: Colors.indigo),
          ),

          if (_dadosValidacao != null) ...[
            const SizedBox(height: 8),
            Text(
              '🎓 Curso: ${_dadosValidacao!['curso_extraido'] ?? 'N/A'}',
              style: TextStyle(color: Colors.cyan),
            ),
            Text(
              '📋 Matriz: ${_dadosValidacao!['matriz_curricular'] ?? 'N/A'}',
              style: TextStyle(color: Colors.cyan),
            ),
            Text(
              '📊 IRA: ${_dadosValidacao!['ira']?.toStringAsFixed(2) ?? 'N/A'}',
              style: TextStyle(color: Colors.blue),
            ),
            Text(
              '📈 Média ponderada: ${_dadosValidacao!['media_ponderada']?.toStringAsFixed(2) ?? 'N/A'}',
              style: TextStyle(color: Colors.blue),
            ),
            Text(
              '📊 Frequência: ${_dadosValidacao!['frequencia_geral']?.toStringAsFixed(2) ?? 'N/A'}%',
              style: TextStyle(color: Colors.blue),
            ),
            Text(
              '⏱️ Horas integralizadas: ${_dadosValidacao!['horas_integralizadas']}h',
              style: TextStyle(color: Colors.blue),
            ),
            if (_dadosValidacao!['pendencias'] != null &&
                _dadosValidacao!['pendencias'] is List &&
                _dadosValidacao!['pendencias'].isNotEmpty)
              Text(
                '⚠️ Pendências: ${(_dadosValidacao!['pendencias'] as List).join(', ')}',
                style: TextStyle(color: Colors.orange),
              ),
          ],

          const SizedBox(height: 16),

          // Lista de disciplinas encontradas
          if (disciplinasEncontradas.isNotEmpty) ...[
            _buildDisciplinasList(
              titulo:
                  '✅ Disciplinas Encontradas (${disciplinasEncontradas.length})',
              disciplinas: disciplinasEncontradas,
              cor: Colors.green,
              isFound: true,
            ),
            const SizedBox(height: 12),
          ],

          // Lista de disciplinas não encontradas
          if (disciplinasNaoEncontradas.isNotEmpty) ...[
            _buildDisciplinasList(
              titulo:
                  '❌ Disciplinas Não Encontradas (${disciplinasNaoEncontradas.length})',
              disciplinas: disciplinasNaoEncontradas,
              cor: Colors.orange,
              isFound: false,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          Text(
            '💡 Dica: Verifique o console para mais detalhes',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '🎯 Processamento automático: Curso e matriz extraídos do PDF',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplinasList({
    required String titulo,
    required List<Map<String, dynamic>> disciplinas,
    required Color cor,
    required bool isFound,
  }) {
    disciplinas.sort((a, b) => a['nivel'].compareTo(b['nivel']));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          titulo,
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconColor: cor,
        collapsedIconColor: cor,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        collapsedBackgroundColor: Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          Container(
            constraints:
                BoxConstraints(maxHeight: getProportionateScreenHeight(500)),
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: disciplinas.length,
                itemBuilder: (context, index) {
                  final disciplina = disciplinas[index];
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${disciplina['codigo'] ?? 'S/CÓDIGO'} - ${disciplina['nome'] ?? 'Nome não disponível'}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (disciplina['situacao'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Situação: ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                disciplina['situacao'].toString(),
                                style: TextStyle(
                                  color: disciplina['situacao']
                                          .toString()
                                          .toLowerCase()
                                          .contains('aprovado')
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (disciplina['creditos'] != null ||
                            disciplina['nivel'] != null) ...[
                          const SizedBox(height: 4),
                          Row(spacing: 16, children: [
                            if (disciplina['creditos'] != null) ...[
                              Text(
                                'Créditos: ${disciplina['creditos']}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (disciplina['nivel'] != null) ...[
                              Text(
                                'Nível: ${disciplina['nivel'] == 0 ? 'Optativa' : disciplina['nivel']}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (disciplina['mencao'] != null) ...[
                              Text(
                                'Mencao: ${disciplina['mencao']}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ]),
                        ],
                        if (disciplina['professor'] != null &&
                            disciplina['professor'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Professor: ${disciplina['professor']}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (!isFound &&
                            disciplina['motivo_nao_encontrada'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Motivo: ${disciplina['motivo_nao_encontrada']}',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassoHistorico extends StatelessWidget {
  final String titulo;
  final Widget descricao;
  final String imagem;
  final String alt;

  const _PassoHistorico({
    required this.titulo,
    required this.descricao,
    required this.imagem,
    required this.alt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 6),
          descricao,
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: (0.08 * 255)),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  imagem,
                  width: 400,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    width: 400,
                    height: 180,
                    alignment: Alignment.center,
                    child: Text(
                      'Imagem não encontrada:\n$imagem',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
