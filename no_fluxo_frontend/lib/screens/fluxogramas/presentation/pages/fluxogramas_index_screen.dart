import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../utils/utils.dart';
import '../../../../widgets/app_navbar.dart';
import '../../../../widgets/graffiti_background.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../data/curso_model.dart';
import '../../services/meu_fluxograma_service.dart';
import 'meu_fluxograma_screen.dart';

class FluxogramasIndexScreen extends StatefulWidget {
  const FluxogramasIndexScreen({super.key});

  @override
  State<FluxogramasIndexScreen> createState() => _FluxogramasIndexScreenState();
}

class _FluxogramasIndexScreenState extends State<FluxogramasIndexScreen> {
  int currentPage = 1;
  final TextEditingController _searchController = TextEditingController();
  String searchText = '';
  bool loaded = false;
  String? errorFound;
  List<CursoModel> cursos = [];

  // Pagination constants
  static const int itemsPerPage = 6;

  void setPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  // Get filtered courses based on search text
  List<CursoModel> get filteredCursos {
    if (searchText.isEmpty) {
      return cursos;
    }
    return cursos.where((curso) {
      return curso.nomeCurso.toLowerCase().contains(searchText.toLowerCase()) ||
          curso.matrizCurricular
              .toLowerCase()
              .contains(searchText.toLowerCase());
    }).toList();
  }

  // Get paginated courses for current page
  List<CursoModel> get paginatedCursos {
    final filtered = filteredCursos;
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= filtered.length) {
      return [];
    }

    return filtered.sublist(
        startIndex, endIndex > filtered.length ? filtered.length : endIndex);
  }

  // Calculate total pages based on filtered results
  int get totalPages {
    final filtered = filteredCursos;
    return (filtered.length / itemsPerPage)
        .ceil()
        .clamp(1, double.infinity)
        .toInt();
  }

  void onSearchChanged(String value) {
    setState(() {
      searchText = value;
      currentPage = 1; // Reset to first page when search changes
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> loadData() async {
    if (loaded) return true;
    loaded = true;

    try {
      final response = await MeuFluxogramaService.getAllCursosMinimal();

      response.fold((l) {
        errorFound = l;
      }, (r) {
        cursos = r;

        var uniqueCursos = Set<String>.from({});
        var actualCursos = List<CursoModel>.from({});

        for (var curso in cursos) {
          if (!uniqueCursos.contains(curso.nomeCurso)) {
            uniqueCursos.add(curso.nomeCurso);
            actualCursos.add(curso);
          }
        }

        cursos = actualCursos;
        cursos.sort((a, b) => a.nomeCurso.compareTo(b.nomeCurso));
      });

      return true;
    } catch (e) {
      errorFound = e.toString();
    }
    return false;
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

    return Scaffold(
      body: FutureBuilder(
          future: loadData(),
          builder: (context, asyncSnapshot) {
            if (!asyncSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (errorFound != null) {
              return Center(child: Text(errorFound!));
            }

            var gridCards = paginatedCursos
                .map((curso) => CourseCard(
                      title: curso.nomeCurso,
                      subtitle: Utils.capitalize(curso.tipoCurso) +
                          " * " +
                          Utils.capitalize(curso.classificacao),
                      credits: curso.totalCreditos.toString() + " créditos",
                      fluxograma: SizedBox(
                        width: 300,
                        height: 120,
                        child: CustomPaint(
                          painter: GenericFluxogramaPainter(
                              fluxogramas[cursos.indexOf(curso) % 6]),
                        ),
                      ),
                    ))
                .toList();

            return Stack(
              children: [
                const GraffitiBackground(),
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
                SafeArea(
                  child: Column(
                    children: [
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
                                                  color: Colors.black
                                                      .withOpacity(0.7),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            children: [
                                              const TextSpan(
                                                  text: 'FLUXOGRAMAS '),
                                              TextSpan(
                                                text: 'DISPONÍVEIS',
                                                style:
                                                    GoogleFonts.permanentMarker(
                                                  fontSize: 48,
                                                  color:
                                                      const Color(0xFFFF3CA5),
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
                                          constraints: const BoxConstraints(
                                              maxWidth: 700),
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
                                          icon: const Icon(
                                              Icons.lightbulb_outline,
                                              color: Colors.white,
                                              size: 22),
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
                                            backgroundColor:
                                                const Color(0xFF6366F1),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
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
                                        final isWide =
                                            constraints.maxWidth > 700;
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
                                                    ? const EdgeInsets.only(
                                                        right: 16)
                                                    : const EdgeInsets.only(
                                                        bottom: 16),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.08),
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
                                                        controller:
                                                            _searchController,
                                                        onChanged: (value) {
                                                          onSearchChanged(
                                                              value);
                                                        },
                                                        decoration:
                                                            InputDecoration(
                                                          hintText:
                                                              'Buscar curso...',
                                                          hintStyle: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.7),
                                                            fontSize: 18,
                                                          ),
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      24,
                                                                  vertical: 18),
                                                        ),
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
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
                                                  _buildFilterButton(
                                                      'TODOS', true),
                                                  const SizedBox(width: 10),
                                                  _buildFilterButton(
                                                      'EXATAS', false),
                                                  const SizedBox(width: 10),
                                                  _buildFilterButton(
                                                      'HUMANAS', false),
                                                  const SizedBox(width: 10),
                                                  _buildFilterButton(
                                                      'SAÚDE', false),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  // Results info
                                  if (filteredCursos.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Mostrando ${paginatedCursos.length} de ${filteredCursos.length} cursos',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFFD1D5DB),
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (totalPages > 1)
                                            Text(
                                              'Página $currentPage de $totalPages',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFFD1D5DB),
                                                fontSize: 16,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  // Grid de cards de cursos
                                  if (paginatedCursos.isEmpty &&
                                      searchText.isNotEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(48),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 64,
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Nenhum curso encontrado',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFFD1D5DB),
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tente buscar por outro termo',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    GridView.count(
                                      crossAxisCount: MediaQuery.of(context)
                                                  .size
                                                  .width >
                                              1100
                                          ? 3
                                          : MediaQuery.of(context).size.width >
                                                  700
                                              ? 2
                                              : 1,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 24,
                                      mainAxisSpacing: 24,
                                      childAspectRatio: 1.2,
                                      children: gridCards,
                                    ),
                                  const SizedBox(height: 48),
                                  // Paginação
                                  if (totalPages > 1) _buildPagination(),
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
            );
          }),
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

  Widget _buildPagination() {
    List<Widget> paginationButtons = [];

    // Previous button
    if (currentPage > 1) {
      paginationButtons.add(
        _PaginationButton(
          text: '‹',
          isActive: false,
          onTap: () => setPage(currentPage - 1),
        ),
      );
      paginationButtons.add(const SizedBox(width: 8));
    }

    // Calculate which page numbers to show
    int startPage = 1;
    int endPage = totalPages;

    // If there are more than 7 pages, show pagination with ellipsis
    if (totalPages > 7) {
      if (currentPage <= 4) {
        // Show first 5 pages + ellipsis + last page
        endPage = 5;
        paginationButtons.addAll(_buildPageNumbers(startPage, endPage));
        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_buildEllipsis());
        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_PaginationButton(
          text: totalPages.toString(),
          isActive: currentPage == totalPages,
          onTap: () => setPage(totalPages),
        ));
      } else if (currentPage >= totalPages - 3) {
        // Show first page + ellipsis + last 5 pages
        paginationButtons.add(_PaginationButton(
          text: '1',
          isActive: currentPage == 1,
          onTap: () => setPage(1),
        ));
        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_buildEllipsis());
        paginationButtons.add(const SizedBox(width: 8));
        startPage = totalPages - 4;
        paginationButtons.addAll(_buildPageNumbers(startPage, totalPages));
      } else {
        // Show first page + ellipsis + current-1, current, current+1 + ellipsis + last page
        paginationButtons.add(_PaginationButton(
          text: '1',
          isActive: currentPage == 1,
          onTap: () => setPage(1),
        ));
        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_buildEllipsis());
        paginationButtons.add(const SizedBox(width: 8));

        startPage = currentPage - 1;
        endPage = currentPage + 1;
        paginationButtons.addAll(_buildPageNumbers(startPage, endPage));

        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_buildEllipsis());
        paginationButtons.add(const SizedBox(width: 8));
        paginationButtons.add(_PaginationButton(
          text: totalPages.toString(),
          isActive: currentPage == totalPages,
          onTap: () => setPage(totalPages),
        ));
      }
    } else {
      // Show all pages if 7 or fewer
      paginationButtons.addAll(_buildPageNumbers(startPage, endPage));
    }

    // Next button
    if (currentPage < totalPages) {
      paginationButtons.add(const SizedBox(width: 8));
      paginationButtons.add(
        _PaginationButton(
          text: '›',
          isActive: false,
          onTap: () => setPage(currentPage + 1),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: paginationButtons,
      ),
    );
  }

  List<Widget> _buildPageNumbers(int start, int end) {
    List<Widget> buttons = [];
    for (int i = start; i <= end; i++) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 8));
      }
      buttons.add(
        _PaginationButton(
          text: i.toString(),
          isActive: currentPage == i,
          onTap: () => setPage(i),
        ),
      );
    }
    return buttons;
  }

  Widget _buildEllipsis() {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: const Text(
        '...',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
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
