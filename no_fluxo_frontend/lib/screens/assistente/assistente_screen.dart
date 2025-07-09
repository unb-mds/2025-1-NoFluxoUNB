import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/environment.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/animated_background.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({Key? key}) : super(key: key);

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.\nMe conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver!'
    }
  ];
  final List<String> _interestTags = [
    'Programação',
    'Dados',
    'Design',
    'Gestão',
    'Pesquisa',
    'Inovação'
  ];
  final List<String> _selectedInterests = [];
  final List<String> _selectedCourses = [];

  // Estado de loading
  bool _isLoading = false;
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  // Função para enviar mensagem ao backend da IA
  Future<String> _enviarMensagemParaIA(String mensagem) async {
    // Troque o IP abaixo pelo IP do seu backend se necessário
    final url =
        Uri.parse('${Environment.apiUrl.split(":")[0]}:4652/assistente');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'materia': mensagem}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['resultado'] ?? data['erro'] ?? 'Sem resposta da IA.';
      } else {
        return 'Erro ao se comunicar com a IA (status: ${response.statusCode}).';
      }
    } catch (e) {
      return 'Erro ao se comunicar com a IA.';
    }
  }

  void _enviarMensagem() async {
    final value = _chatController.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        _messages.add({'isUser': true, 'text': value});
        _chatController.clear();
        _isLoading = true;
      });

      // Iniciar animação de loading
      _loadingController.repeat();

      final resposta = await _enviarMensagemParaIA(value);

      // Parar animação de loading
      _loadingController.stop();

      setState(() {
        _isLoading = false;
        _messages.add({'isUser': false, 'text': resposta});
      });
    }
  }

  void _enviarMensagemRapida(String tag) async {
    // Criar uma mensagem mais elaborada baseada na tag selecionada
    String mensagem = _criarMensagemPorTag(tag);

    setState(() {
      _messages.add({'isUser': true, 'text': mensagem});
      _isLoading = true;
    });

    // Iniciar animação de loading
    _loadingController.repeat();

    final resposta = await _enviarMensagemParaIA(mensagem);

    // Parar animação de loading
    _loadingController.stop();

    setState(() {
      _isLoading = false;
      _messages.add({'isUser': false, 'text': resposta});
    });
  }

  String _criarMensagemPorTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'programação':
        return 'Estou interessado em matérias de programação. Quais disciplinas da UnB você recomenda para desenvolver habilidades de programação?';
      case 'dados':
        return 'Tenho interesse em trabalhar com dados e análise. Que matérias relacionadas a ciência de dados, estatística e análise você sugere?';
      case 'design':
        return 'Gostaria de aprender sobre design e experiência do usuário. Quais disciplinas da UnB abordam design, UX/UI e áreas criativas?';
      case 'gestão':
        return 'Quero desenvolver habilidades de gestão e liderança. Que matérias relacionadas a administração, gestão de projetos e empreendedorismo você recomenda?';
      case 'pesquisa':
        return 'Tenho interesse em pesquisa acadêmica e científica. Quais disciplinas podem me ajudar a desenvolver habilidades de pesquisa e metodologia científica?';
      case 'inovação':
        return 'Estou interessado em inovação e tecnologia. Que matérias abordam temas como inovação, startups, tecnologias emergentes e empreendedorismo tecnológico?';
      default:
        return 'Estou interessado em $tag. Que matérias relacionadas a essa área você recomenda?';
    }
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 4),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFB72EFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'A',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(4),
                  topRight: const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _loadingAnimation,
                    builder: (context, child) {
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(
                                0.5 + (0.5 * _loadingAnimation.value),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(
                                0.3 + (0.7 * _loadingAnimation.value),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'IA está pensando...',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg['isUser'])
            Container(
              margin: const EdgeInsets.only(right: 12, top: 4),
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFB72EFF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'A',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: msg['isUser']
                    ? const Color(0xFF8B5CF6).withOpacity(0.8)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(msg['isUser'] ? 16 : 4),
                  topRight: Radius.circular(msg['isUser'] ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: MarkdownBody(
                data: msg['text'],
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  strong: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestTags() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 4),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFB72EFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'A',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(4),
                  topRight: const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você pode selecionar algumas áreas de interesse:',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestTags.map((tag) {
                      final selected = _selectedInterests.contains(tag);
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedInterests.remove(tag);
                              } else {
                                _selectedInterests.add(tag);
                              }
                            });
                            // Enviar automaticamente a tag selecionada como mensagem
                            _enviarMensagemRapida(tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF22C55E)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF22C55E)
                                    : Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              AppNavbar(isFluxogramasPage: true),
              Expanded(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chat principal (2/3)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header do chat
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    'ASSISTENTE ',
                                    style: GoogleFonts.permanentMarker(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'NOFLUXO',
                                    style: GoogleFonts.permanentMarker(
                                      color: const Color(0xFFFF277E),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Online',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Chat Container
                              Expanded(
                                child: Center(
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 900),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 24, horizontal: 24),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: _messages.length +
                                                  (_messages.length == 1
                                                      ? 1
                                                      : 0) +
                                                  (_isLoading ? 1 : 0),
                                              itemBuilder: (context, index) {
                                                if (index < _messages.length) {
                                                  final msg = _messages[index];
                                                  return _buildMessage(msg);
                                                } else if (index ==
                                                        _messages.length &&
                                                    _messages.length == 1) {
                                                  return _buildInterestTags();
                                                } else if (_isLoading &&
                                                    index ==
                                                        _messages.length +
                                                            (_messages.length ==
                                                                    1
                                                                ? 1
                                                                : 0)) {
                                                  return _buildLoadingMessage();
                                                } else {
                                                  return _buildInterestTags();
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        // Campo de input colado na base
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.08),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.18),
                                                    ),
                                                  ),
                                                  child: TextField(
                                                    controller: _chatController,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Digite sua mensagem...',
                                                      hintStyle:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white54,
                                                        fontSize: 16,
                                                      ),
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 20,
                                                        vertical: 16,
                                                      ),
                                                    ),
                                                    onSubmitted: (value) {
                                                      if (value
                                                          .trim()
                                                          .isNotEmpty) {
                                                        _enviarMensagem();
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              GestureDetector(
                                                onTap: () {
                                                  final value = _chatController
                                                      .text
                                                      .trim();
                                                  if (value.isNotEmpty) {
                                                    _enviarMensagem();
                                                  }
                                                },
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                      colors: [
                                                        Color(0xFF8B5CF6),
                                                        Color(0xFFEC4899)
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                  ),
                                                  child: const Icon(
                                                    Icons.send,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Painel lateral (1/3)
                        Expanded(
                          flex: 1,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Matérias Selecionadas
                                Container(
                                  width: 500,
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Matérias Selecionadas',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      if (_selectedCourses.isEmpty)
                                        Column(
                                          children: [
                                            Icon(
                                              Icons.menu_book,
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              size: 48,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Nenhuma matéria selecionada',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Column(
                                          children: _selectedCourses
                                              .map(
                                                (course) => Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 8),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          course,
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedCourses
                                                                .remove(course);
                                                          });
                                                        },
                                                        child: Icon(
                                                          Icons.close,
                                                          color: Colors.white
                                                              .withOpacity(0.7),
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {},
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF8B5CF6),
                                                  Color(0xFFEC4899)
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'ADICIONAR AO FLUXOGRAMA',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Seu Fluxograma
                                Container(
                                  width: 500,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Seu Fluxograma',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: 460,
                                            height: 300,
                                            child: _buildFluxogramPreview(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Botão fora do container do SVG
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.1),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {},
                                    child: Text(
                                      'VER FLUXOGRAMA COMPLETO',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFluxogramPreview() {
    return CustomPaint(
      painter: _FluxogramPreviewPainter(),
      child: Container(),
    );
  }
}

class _FluxogramPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;

    // Semester headers
    _drawText(canvas, '1º Semestre', const Offset(50, 20), 12);
    _drawText(canvas, '2º Semestre', const Offset(50, 90), 12);
    _drawText(canvas, '3º Semestre', const Offset(50, 160), 12);
    _drawText(canvas, '4º Semestre', const Offset(50, 230), 12);

    // Semester 1 - Completed (green)
    _drawSubjectBox(
        canvas, 'Algoritmos', const Offset(60, 55), const Color(0xFF4ADE80));
    _drawSubjectBox(
        canvas, 'Cálculo 1', const Offset(150, 55), const Color(0xFF4ADE80));
    _drawSubjectBox(
        canvas, 'APC', const Offset(240, 55), const Color(0xFF4ADE80));
    _drawSubjectBox(canvas, 'Introdução ES', const Offset(330, 55),
        const Color(0xFF4ADE80));

    // Semester 2 - Completed (green)
    _drawSubjectBox(
        canvas, 'EDA', const Offset(60, 125), const Color(0xFF4ADE80));
    _drawSubjectBox(
        canvas, 'Cálculo 2', const Offset(150, 125), const Color(0xFF4ADE80));
    _drawSubjectBox(
        canvas, 'OO', const Offset(240, 125), const Color(0xFF4ADE80));
    _drawSubjectBox(
        canvas, 'Requisitos', const Offset(330, 125), const Color(0xFF4ADE80));

    // Semester 3 - Current (purple/red)
    _drawSubjectBox(
        canvas, 'Projeto 1', const Offset(60, 195), const Color(0xFFA78BFA));
    _drawSubjectBox(
        canvas, 'Métodos', const Offset(150, 195), const Color(0xFFA78BFA));
    _drawSubjectBox(
        canvas, 'Arquitetura', const Offset(240, 195), const Color(0xFFA78BFA));
    _drawSubjectBox(canvas, 'Bancos de Dados', const Offset(330, 195),
        const Color(0xFFFB7185));

    // Semester 4 - Future (gray)
    _drawSubjectBox(
        canvas, 'Projeto 2', const Offset(60, 265), const Color(0xFF475569),
        opacity: 0.4);
    _drawSubjectBox(
        canvas, 'Qualidade', const Offset(150, 265), const Color(0xFF475569),
        opacity: 0.4);
    _drawSubjectBox(
        canvas, 'Testes', const Offset(240, 265), const Color(0xFF475569),
        opacity: 0.4);
    _drawSubjectBox(
        canvas, 'GPP', const Offset(330, 265), const Color(0xFF475569),
        opacity: 0.4);

    // Connection lines
    for (int i = 0; i < 4; i++) {
      final x = 60.0 + (i * 90);
      canvas.drawLine(
        Offset(x, 75),
        Offset(x, 105),
        paint,
      );
      canvas.drawLine(
        Offset(x, 145),
        Offset(x, 175),
        paint,
      );
      canvas.drawLine(
        Offset(x, 215),
        Offset(x, 245),
        paint,
      );
    }
  }

  void _drawSubjectBox(Canvas canvas, String text, Offset center, Color color,
      {double opacity = 0.8}) {
    final rect = Rect.fromCenter(
      center: center,
      width: 80,
      height: 40,
    );

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );

    if (opacity < 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        borderPaint,
      );
    }

    _drawText(canvas, text, center, 10, opacity: opacity);
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize,
      {double opacity = 1.0}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: fontSize,
          fontFamily: 'Arial',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
