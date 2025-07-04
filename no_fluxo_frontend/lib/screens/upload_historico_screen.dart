import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_navbar.dart';
import '../widgets/animated_background.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:dotted_border/dotted_border.dart';

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
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'html'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileName = result.files.single.name;
        });
        await uploadPdfBytes(
            result.files.single.bytes!, result.files.single.name);
        await _simulateUpload();
      }
    } catch (e) {
      // Debugger e mensagem de erro
      debugPrint('Erro ao selecionar o arquivo: ' + e.toString());
      assert(false, 'Erro ao selecionar o arquivo: ' + e.toString());
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

  void _continueToFlowchart() {
    // Navegar para a tela do fluxograma
    context.go('/fluxogramas');
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
            child: Column(
              children: [
                // Navbar padrão
                const AppNavbar(),
                const Spacer(),
                // Container de Upload Principal
                Center(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 300),
                    child: _buildUploadContainer(),
                  ),
                ),
                const SizedBox(height: 32),
                // Botão de ajuda (apenas no estado inicial)
                if (_uploadState == UploadState.initial)
                  Center(
                    child: _buildHelpButton(),
                  ),
                const Spacer(),
              ],
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
        double width = 260;
        double fontSize = 16;
        EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16);
        if (constraints.maxWidth < 400) {
          width = constraints.maxWidth * 0.95;
          fontSize = 14;
          padding = const EdgeInsets.symmetric(vertical: 12);
        }
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

Future<void> uploadPdf(File file) async {
  try {
    var uri = Uri.parse('http://localhost:3000/fluxograma/read_pdf');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('pdf', file.path));
    var response = await request.send();

    if (response.statusCode == 200) {
      print('PDF enviado e processado com sucesso!');
      // Trate a resposta aqui
    } else {
      print('Erro ao enviar PDF: ${response.statusCode}');
    }
  } catch (e) {
    print('Erro ao enviar PDF: $e');
  }
}

Future<void> uploadPdfBytes(Uint8List bytes, String fileName) async {
  try {
    var uri = Uri.parse('http://localhost:3000/fluxograma/read_pdf');
    var request = http.MultipartRequest('POST', uri);

    // Adiciona o arquivo como bytes
    request.files.add(
      http.MultipartFile.fromBytes(
        'pdf', // nome do campo esperado pelo backend
        bytes,
        filename: fileName,
        contentType: MediaType('application',
            'pdf'), // precisa importar 'package:http_parser/http_parser.dart'
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      print('PDF enviado e processado com sucesso!');
      // Trate a resposta aqui
    } else {
      print('Erro ao enviar PDF: ${response.statusCode}');
    }
  } catch (e) {
    print('Erro ao enviar PDF: $e');
  }
}
