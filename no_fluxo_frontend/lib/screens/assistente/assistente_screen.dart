import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/graffiti_background.dart';
import 'dart:ui';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({Key? key}) : super(key: key);

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Stack(
        children: [
          const GraffitiBackground(),
          Column(
            children: [
              AppNavbar(isFluxogramasPage: true),
              Expanded(
                child: SafeArea(
                  child: Row(
                    children: [
                      // Chat principal
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título estilizado
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  children: [
                                    Text(
                                      'ASSISTENTE ',
                                      style: GoogleFonts.permanentMarker(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      'NOFLUXO',
                                      style: GoogleFonts.permanentMarker(
                                        color: Color(0xFFFF277E),
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Mensagens do chat
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 24, sigmaY: 24),
                                    child: Container(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: _messages.length,
                                              itemBuilder: (context, index) {
                                                final msg = _messages[index];
                                                return Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (!msg['isUser'])
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            right: 12, top: 4),
                                                        width: 40,
                                                        height: 40,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color:
                                                              Color(0xFFB72EFF),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            'A',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 22,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Expanded(
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            vertical: 8),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(20),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: msg['isUser']
                                                              ? Colors.white
                                                                  .withOpacity(
                                                                      0.08)
                                                              : Colors.white
                                                                  .withOpacity(
                                                                      0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(22),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                      0.08),
                                                              blurRadius: 12,
                                                              offset:
                                                                  const Offset(
                                                                      0, 4),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          msg['text'],
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          // Chips de interesse dentro de um balão
                                          if (_messages.length == 1) ...[
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      right: 12, top: 4),
                                                  width: 40,
                                                  height: 40,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFFB72EFF),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'A',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 22,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            28),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.13),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              22),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Você pode selecionar algumas áreas de interesse:',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children:
                                                              _interestTags
                                                                  .map((tag) {
                                                            final selected =
                                                                _selectedInterests
                                                                    .contains(
                                                                        tag);
                                                            return GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (selected) {
                                                                    _selectedInterests
                                                                        .remove(
                                                                            tag);
                                                                  } else {
                                                                    _selectedInterests
                                                                        .add(
                                                                            tag);
                                                                  }
                                                                });
                                                              },
                                                              child: Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20,
                                                                    vertical:
                                                                        10),
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        right:
                                                                            12),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: selected
                                                                      ? Color(
                                                                          0xFF22C55E)
                                                                      : Colors
                                                                          .transparent,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              30),
                                                                  border: Border
                                                                      .all(
                                                                    color: selected
                                                                        ? Color(
                                                                            0xFF22C55E)
                                                                        : Colors
                                                                            .white
                                                                            .withOpacity(0.3),
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  tag,
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        18,
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
                                          ],
                                          const SizedBox(height: 18),
                                          // Campo de input
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.18)),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: _chatController,
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 18),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Digite sua mensagem...',
                                                      hintStyle:
                                                          GoogleFonts.poppins(
                                                              color: Colors
                                                                  .white54,
                                                              fontSize: 18),
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 24,
                                                              vertical: 18),
                                                    ),
                                                    onSubmitted: (value) {
                                                      if (value
                                                          .trim()
                                                          .isNotEmpty) {
                                                        setState(() {
                                                          _messages.add({
                                                            'isUser': true,
                                                            'text': value.trim()
                                                          });
                                                          _chatController
                                                              .clear();
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      final value =
                                                          _chatController.text
                                                              .trim();
                                                      if (value.isNotEmpty) {
                                                        setState(() {
                                                          _messages.add({
                                                            'isUser': true,
                                                            'text': value
                                                          });
                                                          _chatController
                                                              .clear();
                                                        });
                                                      }
                                                    },
                                                    child: ClipOval(
                                                      child: Container(
                                                        width: 44,
                                                        height: 44,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Color(0xFF2196F3),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                            Icons.send,
                                                            color: Colors.white,
                                                            size: 26),
                                                      ),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Painel lateral
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.only(
                              top: 24, bottom: 24, right: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white10, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Matérias Selecionadas',
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 120,
                                        child: _selectedCourses.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.menu_book,
                                                        color: Colors.white24,
                                                        size: 48),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                        'Nenhuma matéria selecionada',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .white38)),
                                                  ],
                                                ),
                                              )
                                            : ListView(
                                                children: _selectedCourses
                                                    .map((course) => ListTile(
                                                          title: Text(course,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                          trailing: IconButton(
                                                            icon: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white54),
                                                            onPressed: () {
                                                              setState(() {
                                                                _selectedCourses
                                                                    .remove(
                                                                        course);
                                                              });
                                                            },
                                                          ),
                                                        ))
                                                    .toList(),
                                              ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8B5CF6),
                                            minimumSize:
                                                const Size.fromHeight(48),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {},
                                          child: const Text(
                                              'ADICIONAR AO FLUXOGRAMA',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Novo bloco: Seu Fluxograma
                                      Text('Seu Fluxograma',
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: Colors.white12,
                                                width: 1),
                                          ),
                                          child: SizedBox(
                                            width: 540,
                                            height: 320,
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter:
                                                        _FluxoLinesPainter(),
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    _fluxoRow([
                                                      'Algoritmos',
                                                      'Cálculo 1',
                                                      'APC',
                                                      'Introdução ES'
                                                    ], const Color(0xFF22C55E)),
                                                    const SizedBox(height: 24),
                                                    _fluxoRow([
                                                      'EDA',
                                                      'Cálculo 2',
                                                      'OO',
                                                      'Requisitos'
                                                    ], const Color(0xFF22C55E)),
                                                    const SizedBox(height: 24),
                                                    _fluxoRow([
                                                      'Projeto 1',
                                                      'Métodos',
                                                      'Arquitetura',
                                                      'Bancos de Dados'
                                                    ], [
                                                      const Color(0xFF8B5CF6),
                                                      const Color(0xFF8B5CF6),
                                                      const Color(0xFF8B5CF6),
                                                      const Color(0xFFF87171)
                                                    ]),
                                                    const SizedBox(height: 24),
                                                    _fluxoRow([
                                                      'Projeto 2',
                                                      'Qualidade',
                                                      'Testes',
                                                      'GPP'
                                                    ], const Color(0xFF27272A)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B2F23),
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {},
                                  child: const Text('VER FLUXOGRAMA COMPLETO',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _fluxoBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500, fontSize: 11),
      ),
    );
  }

  Widget _fluxoRow(List<String> nomes, dynamic cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(nomes.length, (i) {
        final c = cor is List ? cor[i] : cor;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 110,
            height: 52,
            child: _fluxoBox(nomes[i], c),
          ),
        );
      }),
    );
  }
}

class _FluxoLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    // Linhas entre blocos
    for (int i = 0; i < 4; i++) {
      final x = (size.width / 4) * (i + 0.5);
      canvas.drawLine(
        Offset(x, 44),
        Offset(x, size.height - 44),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
