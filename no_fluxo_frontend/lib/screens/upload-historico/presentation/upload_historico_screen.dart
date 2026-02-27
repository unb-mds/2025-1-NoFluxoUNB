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
          suspensoes: [],
          anoAtual: "",
          dadosFluxograma: [],
          matricula: "",
          semestreAtual: 0,
          horasIntegralizadas: 0,
          matrizCurricular: "");

      dadosFluxograma.nomeCurso = _dadosValidacao!['curso_extraido'];

      dadosFluxograma.matricula = _dadosExtraidos!["matricula"];

      dadosFluxograma.matrizCurricular = _dadosExtraidos!["matriz_curricular"];

      dadosFluxograma.ira = _dadosExtraidos!["media_ponderada"];

      dadosFluxograma.suspensoes =
          List<String>.from(_dadosExtraidos!["suspensoes"] ?? []);

      dadosFluxograma.semestreAtual = _dadosExtraidos!["numero_semestre"];

      dadosFluxograma.anoAtual = _dadosExtraidos!["semestre_atual"];

      dadosFluxograma.horasIntegralizadas =
          _dadosValidacao!["horas_integralizadas"];

      dadosFluxograma.dadosFluxograma = List.generate(20, (index) => []);

      for (var materiaCasada in _disciplinasCasadas!) {
        var nivel = materiaCasada["nivel"];

        nivel ??= 0;

        try {
          dadosFluxograma.dadosFluxograma[nivel]
              .add(DadosMateria.fromJson(materiaCasada));
        } catch (e) {
          print(e);
        }
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
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 40 : 16,
            vertical: MediaQuery.of(context).size.height > 800 ? 40 : 16,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = MediaQuery.of(context).size.width > 600;
              final isMobile = MediaQuery.of(context).size.width <= 600;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 700 : double.infinity,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header com título e botão de fechar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Como obter seu histórico acadêmico',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A202C),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey[500],
                                size: isMobile ? 24 : 28,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              splashRadius: 22,
                              tooltip: 'Fechar',
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 16 : 8),
                        // Passo 1
                        _PassoHistorico(
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
                                    text:
                                        ' com seu login e senha institucional.'),
                              ],
                              style: TextStyle(
                                color: Color(0xFF1A202C),
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                          imagem: 'assets/help/tela_de_cadastro.png',
                          alt: 'Tela de login do SIGAA',
                          isMobile: isMobile,
                        ),
                        // Passo 2
                        _PassoHistorico(
                          titulo: '2º PASSO - Selecione "Emitir Histórico"',
                          descricao: Text(
                            'No menu lateral, clique em Ensino e depois em Emitir Histórico.',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          imagem: 'assets/help/emitir_historico.png',
                          alt: 'Menu Emitir Histórico no SIGAA',
                          isMobile: isMobile,
                        ),
                        // Passo 3
                        _PassoHistorico(
                          titulo:
                              '3º PASSO - Faça o upload do PDF para o NoFluxoUNB',
                          descricao: Text(
                            'Salve o arquivo PDF gerado em seu computador e faça o upload nesta página.',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          imagem: 'assets/help/historico_baixado.png',
                          alt: 'Exemplo de histórico acadêmico gerado',
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B469B),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 24 : 32,
                                vertical: isMobile ? 12 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Entendi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 16 : 18,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fundo animado com círculos coloridos borrados
          const AnimatedBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const AppNavbar(),
                      SizedBox(height: _getResponsiveHeight(context, 32)),
                      Center(
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(
                            horizontal: _getResponsiveHorizontalMargin(context),
                          ),
                          child: _buildUploadContainer(),
                        ),
                      ),
                      SizedBox(height: _getResponsiveHeight(context, 32)),
                      if (_uploadState == UploadState.initial)
                        Center(
                          child: _buildHelpButton(),
                        ),
                      SizedBox(height: _getResponsiveHeight(context, 32)),
                      if (_disciplinasCasadas != null) ...[
                        SizedBox(height: _getResponsiveHeight(context, 24)),
                        _buildResultadoProcessamento(),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para responsividade
  double _getResponsiveHorizontalMargin(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 300;
    } else if (screenWidth > 800) {
      return 100;
    } else if (screenWidth > 600) {
      return 50;
    } else {
      return 16;
    }
  }

  double _getResponsiveHeight(BuildContext context, double baseHeight) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) {
      return baseHeight * 0.7;
    } else if (screenHeight < 800) {
      return baseHeight * 0.85;
    }
    return baseHeight;
  }

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) {
      return baseFontSize * 0.8;
    } else if (screenWidth < 600) {
      return baseFontSize * 0.9;
    }
    return baseFontSize;
  }

  Widget _buildHelpButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        double maxWidth = isMobile ? screenWidth * 0.9 : (isTablet ? 500 : 800);
        EdgeInsets padding = isMobile
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        double fontSize = isMobile ? 14 : (isTablet ? 15 : 16);

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Flexible(
                            child: Text(
                              'Como obter seu histórico acadêmico?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: isMobile ? 2 : 1,
                              textAlign: TextAlign.center,
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
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        double maxWidth =
            isMobile ? screenWidth * 0.95 : (isTablet ? 600 : 700);
        double horizontalPadding = isMobile ? 16 : (isTablet ? 24 : 32);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -5 * _hoverAnimation.value),
                  child: DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      color: Colors.white,
                      strokeWidth: isMobile ? 1.5 : 2,
                      radius: Radius.circular(isMobile ? 12 : 16),
                      dashPattern: isMobile ? [6, 4] : [8, 6],
                      padding: EdgeInsets.zero,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(horizontalPadding),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15 + (0.1 * _hoverAnimation.value)),
                        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

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
                        width: isMobile ? 60 : (isTablet ? 70 : 80),
                        height: isMobile ? 60 : (isTablet ? 70 : 80),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            isMobile ? 30 : (isTablet ? 35 : 40),
                          ),
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                          size: isMobile ? 30 : (isTablet ? 35 : 40),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 24)),

                // Texto principal
                Text(
                  'Arraste seu histórico acadêmico aqui',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : (isTablet ? 20 : 24),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isMobile ? 12 : (isTablet ? 14 : 16)),

                // Texto "ou"
                Text(
                  'ou',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : (isTablet ? 14 : 16)),

                // Botão de seleção com animação hover
                _buildUploadButton(),
                SizedBox(height: isMobile ? 12 : (isTablet ? 14 : 16)),

                // Formatos aceitos
                Text(
                  'Somente arquivos PDF são aceitos',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        double buttonWidth =
            isMobile ? screenWidth * 0.7 : (isTablet ? 280 : 320);
        double fontSize = isMobile ? 14 : (isTablet ? 15 : 16);
        double iconSize = isMobile ? 18 : (isTablet ? 20 : 24);

        return MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: AnimatedBuilder(
            animation: _hoverAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -2 * _hoverAnimation.value),
                child: SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(
                      Icons.upload_file,
                      color: Colors.white,
                      size: iconSize,
                    ),
                    label: Text(
                      'Selecionar Histórico',
                      style: TextStyle(
                        fontSize: fontSize,
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
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 12 : (isTablet ? 14 : 16),
                      ),
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
      },
    );
  }

  Widget _buildUploadingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Text(
              'Processando seu histórico...',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 24)),

            // Barra de progresso com animação de gradiente
            Container(
              width: double.infinity,
              height: isMobile ? 12 : (isTablet ? 14 : 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
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
                              borderRadius:
                                  BorderRadius.circular(isMobile ? 6 : 8),
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
            SizedBox(height: isMobile ? 12 : (isTablet ? 14 : 16)),

            // Texto de progresso
            Text(
              '${_progress.toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card de sucesso com borda pontilhada branca
              DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  color: Colors.white,
                  strokeWidth: isMobile ? 1.5 : 2,
                  radius: Radius.circular(isMobile ? 16 : 20),
                  dashPattern: isMobile ? [6, 4] : [8, 6],
                  padding: EdgeInsets.zero,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : (isTablet ? 26 : 32),
                    vertical: isMobile ? 24 : (isTablet ? 30 : 36),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone de sucesso com círculo verde
                      Container(
                        width: isMobile ? 48 : (isTablet ? 56 : 64),
                        height: isMobile ? 48 : (isTablet ? 56 : 64),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.greenAccent,
                            width: isMobile ? 3 : 4,
                            style: BorderStyle.solid,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                          color: Colors.transparent,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.greenAccent,
                            size: isMobile ? 24 : (isTablet ? 32 : 40),
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 16 : (isTablet ? 20 : 24)),
                      // Título
                      Text(
                        'Histórico processado com sucesso!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : (isTablet ? 20 : 24),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 8 : (isTablet ? 10 : 12)),
                      // Subtítulo
                      Text(
                        'Seu fluxograma personalizado está sendo gerado.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 16 : (isTablet ? 18 : 20)),
                      // Botão azul destacado com animação hover
                      _buildContinueButton(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 20 : (isTablet ? 26 : 32)),
              // Exibição do arquivo selecionado com animação hover
              if (_fileName != null) _buildFileItem(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileItem() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        double fontSize = isMobile ? 13 : (isTablet ? 14 : 15);
        double iconSize = isMobile ? 18 : (isTablet ? 20 : 22);
        EdgeInsets contentPadding = isMobile
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arquivo selecionado:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 2.0 : 4.0,
                    ),
                    child: Icon(
                      Icons.insert_drive_file_rounded,
                      color: Colors.white,
                      size: iconSize,
                    ),
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
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        return MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: AnimatedBuilder(
            animation: _hoverAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -2 * _hoverAnimation.value),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _continueToFlowchart,
                    label: Text(
                      'Continuar para o Fluxograma',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
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
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 10 : (isTablet ? 11 : 12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4 + (2 * _hoverAnimation.value),
                      shadowColor: Colors.transparent,
                      minimumSize: Size.fromHeight(isMobile ? 40 : 48),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;

        final cursosList = (errorData['cursos_disponiveis'] is List)
            ? errorData['cursos_disponiveis']
            : (errorData['cursos_disponiveis'] != null
                ? [errorData['cursos_disponiveis']]
                : []);

        return AlertDialog(
          title: Text(
            'Selecione seu curso',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
            ),
          ),
          content: SizedBox(
            width: isMobile ? double.maxFinite : 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorData['message'] ??
                      'Por favor, selecione o curso correto:',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                if (errorData['palavras_chave_encontradas'] != null) ...[
                  SizedBox(height: isMobile ? 6 : 8),
                  Text(
                    'Palavras-chave encontradas: ${(errorData['palavras_chave_encontradas'] as List).join(', ')}',
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                SizedBox(height: isMobile ? 12 : 16),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cursosList.length,
                      itemBuilder: (context, index) {
                        final curso = cursosList[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 16,
                            vertical: isMobile ? 4 : 8,
                          ),
                          title: Text(
                            curso['nome_curso'] ?? '',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          subtitle: curso['matriz_curricular'] != null
                              ? Text(
                                  'Matriz: ${curso['matriz_curricular']}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            _selecionarCurso(curso);
                          },
                        );
                      },
                    ),
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
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

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
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : (isTablet ? 32 : 48),
          ),
          padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 14 : 16)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📊 Resultado do Processamento:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : (isTablet ? 17 : 18),
                ),
              ),
              SizedBox(height: isMobile ? 8 : (isTablet ? 10 : 12)),

              // Resumo geral
              _buildInfoText(
                '📋 Total de disciplinas processadas: ${_disciplinasCasadas!.length}',
                Colors.white,
                isMobile,
              ),
              _buildInfoText(
                '✅ Disciplinas encontradas no banco: ${disciplinasEncontradas.length}',
                Colors.green,
                isMobile,
              ),
              _buildInfoText(
                '❌ Disciplinas não encontradas: ${disciplinasNaoEncontradas.length}',
                Colors.orange,
                isMobile,
              ),

              if (_materiasOptativas != null) ...[
                SizedBox(height: isMobile ? 6 : 8),
                _buildInfoText(
                  '🎯 Matérias optativas: ${_materiasOptativas!.length}',
                  Colors.purple,
                  isMobile,
                ),
              ],

              _buildInfoText(
                '👨‍🏫 Disciplinas com professor: ${_disciplinasCasadas!.where((d) => d['professor'] != null && d['professor'].toString().isNotEmpty).length}',
                Colors.indigo,
                isMobile,
              ),

              if (_dadosValidacao != null) ...[
                SizedBox(height: isMobile ? 6 : 8),
                _buildInfoText(
                  '🎓 Curso: ${_dadosValidacao!['curso_extraido'] ?? 'N/A'}',
                  Colors.cyan,
                  isMobile,
                ),
                _buildInfoText(
                  '📋 Matriz: ${_dadosValidacao!['matriz_curricular'] ?? 'N/A'}',
                  Colors.cyan,
                  isMobile,
                ),
                _buildInfoText(
                  '📊 IRA: ${_dadosValidacao!['ira']?.toStringAsFixed(2) ?? 'N/A'}',
                  Colors.blue,
                  isMobile,
                ),
                _buildInfoText(
                  '📈 Média ponderada: ${_dadosValidacao!['media_ponderada']?.toStringAsFixed(2) ?? 'N/A'}',
                  Colors.blue,
                  isMobile,
                ),
                _buildInfoText(
                  '📊 Frequência: ${_dadosValidacao!['frequencia_geral']?.toStringAsFixed(2) ?? 'N/A'}%',
                  Colors.blue,
                  isMobile,
                ),
                _buildInfoText(
                  '⏱️ Horas integralizadas: ${_dadosValidacao!['horas_integralizadas']}h',
                  Colors.blue,
                  isMobile,
                ),
                if (_dadosValidacao!['pendencias'] != null &&
                    _dadosValidacao!['pendencias'] is List &&
                    _dadosValidacao!['pendencias'].isNotEmpty)
                  _buildInfoText(
                    '⚠️ Pendências: ${(_dadosValidacao!['pendencias'] as List).join(', ')}',
                    Colors.orange,
                    isMobile,
                  ),
              ],

              SizedBox(height: isMobile ? 12 : (isTablet ? 14 : 16)),

              // Lista de disciplinas encontradas
              if (disciplinasEncontradas.isNotEmpty) ...[
                _buildDisciplinasList(
                  titulo:
                      '✅ Disciplinas Encontradas (${disciplinasEncontradas.length})',
                  disciplinas: disciplinasEncontradas,
                  cor: Colors.green,
                  isFound: true,
                ),
                SizedBox(height: isMobile ? 8 : (isTablet ? 10 : 12)),
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
                SizedBox(height: isMobile ? 8 : (isTablet ? 10 : 12)),
              ],

              SizedBox(height: isMobile ? 6 : 8),
              _buildInfoText(
                '💡 Dica: Verifique o console para mais detalhes',
                Colors.white70,
                isMobile,
                fontSize: isMobile ? 10 : 12,
              ),
              SizedBox(height: isMobile ? 2 : 4),
              _buildInfoText(
                '🎯 Processamento automático: Curso e matriz extraídos do PDF',
                Colors.green,
                isMobile,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoText(
    String text,
    Color color,
    bool isMobile, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 2 : 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? (isMobile ? 12 : 14),
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  Widget _buildDisciplinasList({
    required String titulo,
    required List<Map<String, dynamic>> disciplinas,
    required Color cor,
    required bool isFound,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;

        disciplinas.sort((a, b) => a['nivel'] != null
            ? a['nivel'].compareTo(b['nivel'])
            : a['nome'].compareTo(b['nome']));

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
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
                constraints: BoxConstraints(
                  maxHeight: isMobile ? 300 : (isTablet ? 400 : 500),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: disciplinas.length,
                    itemBuilder: (context, index) {
                      final disciplina = disciplinas[index];
                      return Container(
                        margin: EdgeInsets.symmetric(
                          vertical: isMobile ? 1 : 2,
                          horizontal: isMobile ? 4 : 8,
                        ),
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
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
                                fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                              ),
                            ),
                            if (disciplina['situacao'] != null) ...[
                              SizedBox(height: isMobile ? 2 : 4),
                              Row(
                                children: [
                                  Text(
                                    'Situação: ',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize:
                                          isMobile ? 10 : (isTablet ? 11 : 12),
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
                                      fontSize:
                                          isMobile ? 10 : (isTablet ? 11 : 12),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (disciplina['creditos'] != null ||
                                disciplina['nivel'] != null) ...[
                              SizedBox(height: isMobile ? 2 : 4),
                              Wrap(
                                spacing: isMobile ? 8 : 16,
                                children: [
                                  if (disciplina['creditos'] != null) ...[
                                    Text(
                                      'Créditos: ${disciplina['creditos']}',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isMobile
                                            ? 10
                                            : (isTablet ? 11 : 12),
                                      ),
                                    ),
                                  ],
                                  if (disciplina['nivel'] != null) ...[
                                    Text(
                                      'Nível: ${disciplina['nivel'] == 0 ? 'Optativa' : disciplina['nivel']}',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isMobile
                                            ? 10
                                            : (isTablet ? 11 : 12),
                                      ),
                                    ),
                                  ],
                                  if (disciplina['mencao'] != null) ...[
                                    Text(
                                      'Mencao: ${disciplina['mencao']}',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isMobile
                                            ? 10
                                            : (isTablet ? 11 : 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            if (disciplina['professor'] != null &&
                                disciplina['professor']
                                    .toString()
                                    .isNotEmpty) ...[
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                'Professor: ${disciplina['professor']}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize:
                                      isMobile ? 10 : (isTablet ? 11 : 12),
                                ),
                              ),
                            ],
                            if (!isFound &&
                                disciplina['motivo_nao_encontrada'] !=
                                    null) ...[
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                'Motivo: ${disciplina['motivo_nao_encontrada']}',
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize:
                                      isMobile ? 10 : (isTablet ? 11 : 12),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (disciplina['ano_periodo'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ano/Período: ${disciplina['ano_periodo']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (disciplina['turma'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Turma: ${disciplina['turma']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (disciplina['frequencia'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Frequência: ${disciplina['frequencia']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (disciplina['tipo_dado'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tipo de dado: ${disciplina['tipo_dado']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (disciplina['carga_horaria'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Carga horária: ${disciplina['carga_horaria']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (disciplina['status'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${disciplina['status']}',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
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
      },
    );
  }
}

class _PassoHistorico extends StatelessWidget {
  final String titulo;
  final Widget descricao;
  final String imagem;
  final String alt;
  final bool isMobile;

  const _PassoHistorico({
    required this.titulo,
    required this.descricao,
    required this.imagem,
    required this.alt,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 24.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 16 : 18,
              color: Color(0xFF1A202C),
            ),
          ),
          SizedBox(height: isMobile ? 4 : 6),
          descricao,
          SizedBox(height: isMobile ? 8 : 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
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
                  width: isMobile ? 280 : 400,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    width: isMobile ? 280 : 400,
                    height: isMobile ? 140 : 180,
                    alignment: Alignment.center,
                    child: Text(
                      'Imagem não encontrada:\n$imagem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: isMobile ? 12 : 14,
                      ),
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
