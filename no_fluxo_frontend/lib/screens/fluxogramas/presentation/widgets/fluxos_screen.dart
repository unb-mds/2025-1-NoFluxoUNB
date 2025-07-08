import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../widgets/app_navbar.dart';
import '../../../../widgets/graffiti_background.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../pages/meu_fluxograma_screen.dart';

class FluxogramasIndexScreen extends StatefulWidget {
  const FluxogramasIndexScreen({super.key});

  @override
  State<FluxogramasIndexScreen> createState() => _FluxogramasIndexScreenState();
}

class _FluxogramasIndexScreenState extends State<FluxogramasIndexScreen> {
  int currentPage = 1;
  final TextEditingController _searchController = TextEditingController();
  String searchText = '';

  void setPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definição dos fluxogramas coloridos
    final fluxogramas = [
      const Color(0xFF8B5CF6), // Computação
      const Color(0xFFFB7185), // Eng. Software
      const Color(0xFFFB923C), // Eng. Elétrica
      const Color(0xFFFACC15), // Administração
      const Color(0xFF4ADE80), // Medicina
      const Color(0xFF38BDF8), // Direito
    ];

    // Cursos de cada página (exemplo: só página 1 tem nomes, as outras são placeholders)
    final List<List<CourseCard>> pages = [
      [
        CourseCard(
          title: 'Ciência da Computação',
          subtitle: 'Bacharelado • 8 semestres',
          credits: '240 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[0]),
            ),
          ),
        ),
        CourseCard(
          title: 'Engenharia de Software',
          subtitle: 'Bacharelado • 10 semestres',
          credits: '252 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[1]),
            ),
          ),
        ),
        CourseCard(
          title: 'Engenharia Elétrica',
          subtitle: 'Bacharelado • 10 semestres',
          credits: '262 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[2]),
            ),
          ),
        ),
        CourseCard(
          title: 'Administração',
          subtitle: 'Bacharelado • 8 semestres',
          credits: '200 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[3]),
            ),
          ),
        ),
        CourseCard(
          title: 'Medicina',
          subtitle: 'Bacharelado • 12 semestres',
          credits: '360 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[4]),
            ),
          ),
        ),
        CourseCard(
          title: 'Direito',
          subtitle: 'Bacharelado • 10 semestres',
          credits: '280 créditos',
          isTranslucent: true,
          fluxograma: SizedBox(
            width: 300,
            height: 120,
            child: CustomPaint(
              painter: GenericFluxogramaPainter(fluxogramas[5]),
            ),
          ),
        ),
      ],
      // Páginas 2 a 8: cards vazios (prontos para receber nomes no futuro)
      for (int p = 2; p <= 8; p++)
        List.generate(
            6,
            (i) => CourseCard(
                  title: '',
                  subtitle: '',
                  credits: '',
                  isTranslucent: true,
                  fluxograma: SizedBox(
                    width: 300,
                    height: 120,
                    child: CustomPaint(
                      painter: GenericFluxogramaPainter(fluxogramas[i]),
                    ),
                  ),
                )),
    ];

    // Filtrar os cards da página atual
    final gridCards = pages[currentPage - 1]
        .where((card) =>
            card.title.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          const GraffitiBackground(),
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          SafeArea(
            child: Column(
              children: [
                // Botão de teste para navegar para MeuFluxogramaScreen
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/meu-fluxograma/Engenharia de Software');
                    },
                    child: const Text('Ver Fluxograma Individual (teste)'),
                  ),
                ),
                AppNavbar(isFluxogramasPage: true),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Título e subtítulo
                            Padding(
                              padding: const EdgeInsets.only(bottom: 48),
                              child: Column(
                                children: [
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: GoogleFonts.permanentMarker(
                                        fontSize: 48,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color:
                                                Colors.black.withOpacity(0.7),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        const TextSpan(text: 'FLUXOGRAMAS '),
                                        TextSpan(
                                          text: 'DISPONÍVEIS',
                                          style: GoogleFonts.permanentMarker(
                                            fontSize: 48,
                                            color: const Color(0xFFFF3CA5),
                                            shadows: [
                                              Shadow(
                                                color: Colors.black
                                                    .withOpacity(0.7),
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 700),
                                    child: Text(
                                      'Escolha o curso para visualizar seu fluxograma completo. Você poderá personalizar adicionando matérias optativas e acompanhar seu progresso.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        color: const Color(0xFFD1D5DB),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      context.go('/assistente');
                                    },
                                    icon: const Icon(Icons.lightbulb_outline,
                                        color: Colors.white, size: 22),
                                    label: Text(
                                      'FALE COM O ASSISTENTE',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 36, vertical: 18),
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      elevation: 8,
                                      shadowColor:
                                          Colors.black.withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Barra de busca e filtros
                            Padding(
                              padding: const EdgeInsets.only(bottom: 40),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 700;
                                  return Flex(
                                    direction: isWide
                                        ? Axis.horizontal
                                        : Axis.vertical,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Barra de busca
                                      Flexible(
                                        flex: isWide ? 5 : 0,
                                        child: Container(
                                          margin: isWide
                                              ? const EdgeInsets.only(right: 16)
                                              : const EdgeInsets.only(
                                                  bottom: 16),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(32),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.18),
                                                width: 2),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _searchController,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      searchText = value;
                                                    });
                                                  },
                                                  decoration: InputDecoration(
                                                    hintText: 'Buscar curso...',
                                                    hintStyle:
                                                        GoogleFonts.poppins(
                                                      color: Colors.white
                                                          .withOpacity(0.7),
                                                      fontSize: 18,
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 24,
                                                            vertical: 18),
                                                  ),
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 18.0),
                                                child: Icon(Icons.search,
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                    size: 26),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Filtros
                                      Flexible(
                                        flex: isWide ? 4 : 0,
                                        child: Row(
                                          mainAxisAlignment: isWide
                                              ? MainAxisAlignment.end
                                              : MainAxisAlignment.center,
                                          children: [
                                            _buildFilterButton('TODOS', true),
                                            const SizedBox(width: 10),
                                            _buildFilterButton('EXATAS', false),
                                            const SizedBox(width: 10),
                                            _buildFilterButton(
                                                'HUMANAS', false),
                                            const SizedBox(width: 10),
                                            _buildFilterButton('SAÚDE', false),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            // Grid de cards de cursos (placeholder)
                            GridView.count(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 1100
                                      ? 3
                                      : MediaQuery.of(context).size.width > 700
                                          ? 2
                                          : 1,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 1.2,
                              children: gridCards,
                            ),
                            const SizedBox(height: 48),
                            // Paginação
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PaginationButton(
                                      text: '1',
                                      isActive: currentPage == 1,
                                      onTap: () => setPage(1)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '2',
                                      isActive: currentPage == 2,
                                      onTap: () => setPage(2)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '3',
                                      isActive: currentPage == 3,
                                      onTap: () => setPage(3)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '4',
                                      isActive: currentPage == 4,
                                      onTap: () => setPage(4)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '5',
                                      isActive: currentPage == 5,
                                      onTap: () => setPage(5)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '6',
                                      isActive: currentPage == 6,
                                      onTap: () => setPage(6)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '7',
                                      isActive: currentPage == 7,
                                      onTap: () => setPage(7)),
                                  const SizedBox(width: 8),
                                  _PaginationButton(
                                      text: '8',
                                      isActive: currentPage == 8,
                                      onTap: () => setPage(8)),
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
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF7C3AED)])
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.white.withOpacity(0.18),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            // Implementar lógica de filtro
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String credits;
  final Widget fluxograma;
  final bool isTranslucent;
  final Color? colorStart;
  final Color? colorEnd;

  const CourseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.credits,
    required this.fluxograma,
    this.isTranslucent = false,
    this.colorStart,
    this.colorEnd,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: const Color(0xFFD1D5DB),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: Center(child: fluxograma)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              credits,
              style: GoogleFonts.poppins(
                color: const Color(0xFFD1D5DB),
                fontSize: 13,
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                elevation: 0,
              ),
              child: Text(
                'VER FLUXOGRAMA',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return isTranslucent
        ? ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.18), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: cardContent,
              ),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: colorStart == null || colorEnd == null
                  ? null
                  : LinearGradient(
                      colors: [colorStart!, colorEnd!],
                      begin: Alignment.topLeft,
                      end: Alignment.topRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: cardContent,
          );
  }
}

// CustomPainter para fluxogramas coloridos
class GenericFluxogramaPainter extends CustomPainter {
  final Color color;
  GenericFluxogramaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rectPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;

    // Desenhar retângulos (semestres)
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 4; col++) {
        double x = 10 + col * 50;
        double y = 10 + row * 30;
        Rect rect = Rect.fromLTWH(x, y, 40, 20);
        RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rrect, rectPaint);
      }
    }

    // Linhas verticais entre semestres
    for (int col = 0; col < 4; col++) {
      double x = 30 + col * 50;
      // Entre 1º e 2º semestre
      canvas.drawLine(Offset(x, 30), Offset(x, 40), linePaint);
      // Entre 2º e 3º semestre
      canvas.drawLine(Offset(x, 60), Offset(x, 70), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Botão de paginação estilizado
class _PaginationButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback? onTap;
  const _PaginationButton(
      {super.key, required this.text, this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.10)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
