import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/environment.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/animated_background.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math';
import 'dart:async';

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
          'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.\nMe conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver! Tente ser o mais curto possível na sua mensagem, para que eu consiga entender melhor o que você quer.'
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

  final List<String> curiosidades = [
    "🐙 Polvo tem três corações\nDois bombeiam sangue para as guelras, e um para o resto do corpo. Quando ele nada, o coração principal para de bater!",
    "☕ Cafeína pode ser encontrada em mais de 60 plantas diferentes\nAlém do café, também tem cafeína no chá, cacau, guaraná, e até em algumas folhas que você provavelmente nunca ouviu falar.",
    "🚀 Astronautas crescem até 5 cm no espaço\nA gravidade menor faz a coluna se expandir temporariamente. Quando voltam pra Terra, voltam ao tamanho normal.",
    "🧬 Você compartilha cerca de 60% do seu DNA com uma banana\nPor mais maluco que pareça, somos todos parte da mesma grande árvore da vida. 🍌",
    "🎨 A cor rosa não existe no espectro de luz visível\nEla é uma ilusão criada pelo cérebro como uma mistura de vermelho e azul — que nem se tocam no arco-íris.",
    "🐶 Cães conseguem sentir o cheiro do tempo\nEles percebem a passagem do tempo com base na concentração de cheiros no ambiente. Meio como se 'cheirassem o passado'.",
    "🔢 O símbolo \"@\" tem diferentes nomes no mundo\nNo Brasil é \"arroba\", mas na Alemanha é \"Klammeraffe\" (macaco-aranha), e em Israel é chamado de \"strudel\".",
    "🌎 A Terra é mais redonda do que uma bola de sinuca oficial\nSe você escalasse a Terra para o tamanho de uma bola de sinuca, ela seria mais lisa que a bola!",
    "🧠 Seu cérebro consome cerca de 20% da sua energia\nMesmo representando só uns 2% do seu peso corporal total.",
    "📷 A primeira foto de um ser humano foi tirada por acaso\nFoi em 1838, por Louis Daguerre. A rua estava vazia, mas um homem parado engraxando os sapatos ficou tempo suficiente para aparecer.",
  ];
  int? _curiosidadeIndex;
  Timer? _curiosidadeTimer;

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
    final url = Uri.parse('${Environment.agentUrl}/assistente');
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

  void _startCuriosidadeTimer() {
    _curiosidadeTimer?.cancel();
    _curiosidadeIndex = Random().nextInt(curiosidades.length);
    _curiosidadeTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      setState(() {
        int novoIndex;
        do {
          novoIndex = Random().nextInt(curiosidades.length);
        } while (novoIndex == _curiosidadeIndex && curiosidades.length > 1);
        _curiosidadeIndex = novoIndex;
      });
    });
  }

  void _stopCuriosidadeTimer() {
    _curiosidadeTimer?.cancel();
  }

  void _enviarMensagem() async {
    final value = _chatController.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        _messages.add({'isUser': true, 'text': value});
        _chatController.clear();
        _isLoading = true;
        _curiosidadeIndex = null;
      });
      _startCuriosidadeTimer();
      _loadingController.repeat();

      final resposta = await _enviarMensagemParaIA(value);

      _loadingController.stop();

      setState(() {
        _isLoading = false;
        _messages.add({'isUser': false, 'text': resposta});
      });
      _stopCuriosidadeTimer();
    }
  }

  void _enviarMensagemRapida(String tag) async {
    String mensagem = _criarMensagemPorTag(tag);

    setState(() {
      _messages.add({'isUser': true, 'text': mensagem});
      _isLoading = true;
      _curiosidadeIndex = null;
    });
    _startCuriosidadeTimer();
    _loadingController.repeat();

    final resposta = await _enviarMensagemParaIA(mensagem);

    _loadingController.stop();

    setState(() {
      _isLoading = false;
      _messages.add({'isUser': false, 'text': resposta});
    });
    _stopCuriosidadeTimer();
  }

  String _criarMensagemPorTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'programação':
        return 'Programação';
      case 'dados':
        return 'Dados';
      case 'design':
        return 'Design';
      case 'gestão':
        return 'Gestão';
      case 'pesquisa':
        return 'Pesquisa';
      case 'inovação':
        return 'Inovação';
      default:
        return 'Estou interessado em $tag. Que matérias relacionadas a essa área você recomenda?';
    }
  }

  Widget _buildLoadingMessage() {
    final curiosidade = curiosidades[_curiosidadeIndex ?? 0];
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
                  Row(
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
                  const SizedBox(height: 10),
                  Text(
                    'Você sabia?',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    curiosidade,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
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
                styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
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
                  em: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  a: GoogleFonts.poppins(
                    color: const Color(0xFF60A5FA),
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                  h1: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h4: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h5: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  h6: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  code: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF22C55E),
                    fontSize: 14,
                    backgroundColor: Colors.black.withOpacity(0.3),
                  ),
                  blockquote: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  del: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                  ),
                  listBullet: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  tableHead: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  tableBody: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  tableCellsDecoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  tableBorder: TableBorder.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  tableCellsPadding: const EdgeInsets.all(8),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF8B5CF6),
                        width: 4,
                      ),
                    ),
                  ),
                  blockquotePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
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
