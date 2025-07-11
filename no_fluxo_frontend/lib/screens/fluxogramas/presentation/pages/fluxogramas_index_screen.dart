import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/widgets/splash_widget.dart';
import '../../../../cache/shared_preferences_helper.dart';
import '../../../../utils/utils.dart';
import '../../../../widgets/app_navbar.dart';
import '../../../../widgets/graffiti_background.dart';
import '../../../../widgets/premium_hover_button.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../data/curso_model.dart';
import '../../services/meu_fluxograma_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:math';

const _hoverGradient = LinearGradient(
  colors: [Color(0xFF7C3AED), Color(0xFFFF3CA5)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const List<BoxShadow> _hoverShadow = [
  BoxShadow(
    color: Color(0x55FF3CA5),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
];

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
  Set<String> classificacoesUnicas = {};

  // Pagination constants
  static const int itemsPerPage = 6;

  String filtroSelecionado = 'TODOS';
  final GlobalKey _dropdownKey = GlobalKey();

  // Getter para filtros dinâmicos baseados nas classificações do banco
  List<Map<String, String>> get filtrosDinamicos {
    List<Map<String, String>> filtros = [
      {'label': 'TODOS', 'valor': ''},
    ];

    // Adicionar as classificações únicas encontradas nos cursos
    for (String classificacao in classificacoesUnicas) {
      if (classificacao.isNotEmpty) {
        filtros.add({
          'label': classificacao.toUpperCase(),
          'valor': classificacao.toLowerCase(),
        });
      }
    }

    return filtros;
  }

  // Cores dinâmicas baseadas no número de classificações
  List<Color> _getCoresParaClassificacao(String classificacao, int index) {
    // Cores diferentes para cada categoria
    Map<String, List<Color>> coresPorCategoria = {
      'TODOS': [
        const Color(0xFF6366F1),
        const Color(0xFF7C3AED)
      ], // Roxo padrão
      'EXATAS': [
        const Color(0xFF4A1D96),
        const Color(0xFFE11D48)
      ], // Roxo escuro para rosa
      'HUMANAS': [
        const Color(0xFF3B82F6),
        const Color(0xFF1D4ED8)
      ], // Azul vibrante
      'SAÚDE': [
        const Color(0xFF059669),
        const Color(0xFF0EA5E9)
      ], // Verde para azul
      'NATUREZA': [
        const Color(0xFF059669),
        const Color(0xFF0EA5E9)
      ], // Verde para azul
      'CIÊNCIAS EXATAS E DA TERRA': [
        const Color(0xFF8B5CF6),
        const Color(0xFFFB7185)
      ], // Violeta para rosa
      'ENGENHARIAS': [
        const Color(0xFFFB923C),
        const Color(0xFFFACC15)
      ], // Laranja para amarelo
      'CIÊNCIAS BIOLÓGICAS': [
        const Color(0xFF4ADE80),
        const Color(0xFF38BDF8)
      ], // Verde para azul claro
      'CIÊNCIAS DA SAÚDE': [
        const Color(0xFF059669),
        const Color(0xFF0EA5E9)
      ], // Verde para azul
      'CIÊNCIAS AGRÁRIAS': [
        const Color(0xFF92400E),
        const Color(0xFFA16207)
      ], // Marrom terra
      'CIÊNCIAS SOCIAIS APLICADAS': [
        const Color(0xFFEA580C),
        const Color(0xFFCA8A04)
      ], // Laranja
      'CIÊNCIAS HUMANAS': [
        const Color(0xFFDC2626),
        const Color(0xFFEF4444)
      ], // Vermelho
      'LINGUÍSTICA, LETRAS E ARTES': [
        const Color(0xFF7C3AED),
        const Color(0xFF9333EA)
      ], // Roxo
    };

    // Primeiro tenta encontrar a classificação exata
    String classificacaoUpper = classificacao.toUpperCase();
    if (coresPorCategoria.containsKey(classificacaoUpper)) {
      return coresPorCategoria[classificacaoUpper]!;
    }

    // Verificações alternativas para garantir que encontre as cores
    if (classificacaoUpper.contains('HUMANAS') ||
        classificacaoUpper.contains('CIÊNCIAS HUMANAS')) {
      return [
        const Color(0xFF3B82F6),
        const Color(0xFF1D4ED8)
      ]; // Azul vibrante
    }

    if (classificacaoUpper.contains('AGRÁRIAS') ||
        classificacaoUpper.contains('AGRÁRIA')) {
      return [const Color(0xFF92400E), const Color(0xFFA16207)]; // Marrom terra
    }

    // Cores de fallback baseadas no index para classificações não mapeadas
    List<List<Color>> coresFallback = [
      [const Color(0xFF6366F1), const Color(0xFF7C3AED)], // Roxo padrão
      [
        const Color(0xFF4A1D96),
        const Color(0xFFE11D48)
      ], // Roxo escuro para rosa
      [
        const Color(0xFF3B82F6),
        const Color(0xFF1D4ED8)
      ], // Azul vibrante (HUMANAS)
      [const Color(0xFF059669), const Color(0xFF0EA5E9)], // Verde para azul
      [const Color(0xFF8B5CF6), const Color(0xFFFB7185)], // Violeta para rosa
      [
        const Color(0xFFFB923C),
        const Color(0xFFFACC15)
      ], // Laranja para amarelo
      [
        const Color(0xFF4ADE80),
        const Color(0xFF38BDF8)
      ], // Verde para azul claro
      [
        const Color(0xFF92400E),
        const Color(0xFFA16207)
      ], // Marrom terra (AGRÁRIAS)
      [const Color(0xFFDC2626), const Color(0xFFEF4444)], // Vermelho
      [const Color(0xFF7C3AED), const Color(0xFF9333EA)], // Roxo
    ];

    return coresFallback[index % coresFallback.length];
  }

  void setPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  // Get filtered courses based on search text and classification
  List<CursoModel> get filteredCursos {
    var lista = cursos;

    // Aplicar filtro por classificação se não for "TODOS"
    if (filtroSelecionado != 'TODOS') {
      lista = lista.where((curso) {
        return curso.classificacao.toLowerCase() ==
            filtroSelecionado.toLowerCase();
      }).toList();
    }

    if (searchText.isNotEmpty) {
      lista = lista.where((curso) {
        return curso.nomeCurso
                .toLowerCase()
                .contains(searchText.toLowerCase()) ||
            curso.matrizCurricular
                .toLowerCase()
                .contains(searchText.toLowerCase());
      }).toList();
    }
    return lista;
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
            // Extrair classificações únicas
            if (curso.classificacao.isNotEmpty) {
              classificacoesUnicas.add(curso.classificacao);
            }
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
              return const Center(child: SplashWidget());
            }

            if (errorFound != null) {
              return Center(child: Text(errorFound!));
            }

            var gridCards = paginatedCursos
                .map((curso) => CourseCard(
                      title: curso.nomeCurso,
                      tipoCurso: Utils.capitalize(curso.tipoCurso),
                      classificacao: Utils.capitalize(curso.classificacao),
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
                                            'Escolha o curso para visualizar seu fluxograma completo. Você poderá personalizar adicionando matérias optativas e acompanhar seu progresso. ${SharedPreferencesHelper.isAnonimo ? '(é necessário fazer login)' : ''}',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              color: const Color(0xFFD1D5DB),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        if (!SharedPreferencesHelper
                                            .isAnonimo) ...[
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 36,
                                                      vertical: 18),
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
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final user =
                                                  SharedPreferencesHelper
                                                      .currentUser;
                                              if (user == null) return;
                                              final result =
                                                  await MeuFluxogramaService
                                                      .deleteFluxogramaUser(
                                                          user.idUser
                                                              .toString(),
                                                          user.token ?? '');
                                              result.fold((l) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Erro ao remover fluxograma: ' +
                                                            l),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }, (r) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Fluxograma removido com sucesso!'),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                context.go('/upload-historico');
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.refresh,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                            label: Text(
                                              'ENVIAR FLUXOGRAMA NOVAMENTE',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 36,
                                                      vertical: 18),
                                              backgroundColor:
                                                  const Color(0xFFFF3CA5),
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
                                        ]
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
                                            _AnimatedGradientDropdownBar(
                                              dropdownKey: _dropdownKey,
                                              child: Builder(
                                                builder: (context) {
                                                  double dropdownWidth = 0;
                                                  final RenderBox? box =
                                                      _dropdownKey
                                                              .currentContext
                                                              ?.findRenderObject()
                                                          as RenderBox?;
                                                  if (box != null) {
                                                    dropdownWidth =
                                                        box.size.width;
                                                  }
                                                  return DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton2<String>(
                                                      value: filtroSelecionado,
                                                      isExpanded: true,
                                                      iconStyleData:
                                                          const IconStyleData(
                                                        icon: Icon(
                                                            Icons
                                                                .arrow_drop_down_circle_rounded,
                                                            color: Colors.white,
                                                            size: 28),
                                                        iconSize: 28,
                                                        iconEnabledColor:
                                                            Colors.white,
                                                      ),
                                                      style: GoogleFonts
                                                          .permanentMarker(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        letterSpacing: 1.2,
                                                      ),
                                                      dropdownStyleData:
                                                          DropdownStyleData(
                                                        width: dropdownWidth > 0
                                                            ? dropdownWidth
                                                            : null,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Color(0xFF232136),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(24),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                      0.18),
                                                              blurRadius: 12,
                                                              offset:
                                                                  Offset(0, 4),
                                                            ),
                                                          ],
                                                        ),
                                                        elevation: 8,
                                                        padding:
                                                            EdgeInsets.zero,
                                                      ),
                                                      onMenuStateChange: (isOpen) =>
                                                          DropdownOpenedNotification(
                                                                  isOpen)
                                                              .dispatch(
                                                                  context),
                                                      menuItemStyleData:
                                                          const MenuItemStyleData(
                                                        height: 48,
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 16),
                                                      ),
                                                      items: filtrosDinamicos
                                                          .map((filtro) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value:
                                                              filtro['label'],
                                                          child:
                                                              _SimpleDropdownItem(
                                                            label: filtro[
                                                                'label']!,
                                                            isSelected:
                                                                filtroSelecionado ==
                                                                    filtro[
                                                                        'label'],
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged:
                                                          (String? value) {
                                                        if (value != null) {
                                                          setState(() {
                                                            filtroSelecionado =
                                                                value;
                                                            currentPage = 1;
                                                          });
                                                          // setStateDropdown(
                                                          //     () {}); // Forçar rebuild para atualizar largura
                                                        }
                                                      },
                                                      buttonStyleData:
                                                          const ButtonStyleData(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          32)),
                                                        ),
                                                        overlayColor:
                                                            MaterialStatePropertyAll(
                                                                Colors
                                                                    .transparent),
                                                      ),
                                                    ),
                                                  );
                                                },
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

  Widget _buildPremiumFilterButton(String label) {
    final isActive = filtroSelecionado == label;

    // Usar mapeamento direto sempre, sem depender do índice
    final colors = _getCoresParaClassificacao(label, 0);

    return PremiumHoverButton(
      label: label,
      isActive: isActive,
      colors: colors,
      onTap: () {
        setState(() {
          filtroSelecionado = label;
          currentPage = 1;
        });
      },
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
  final String? subtitle; // Manter para compatibilidade
  final String? tipoCurso;
  final String? classificacao;
  final String credits;
  final Widget fluxograma;
  final bool isTranslucent;
  final Color? colorStart;
  final Color? colorEnd;

  const CourseCard({
    super.key,
    required this.title,
    this.subtitle,
    this.tipoCurso,
    this.classificacao,
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
        // Se tipoCurso e classificacao são fornecidos separadamente
        if (tipoCurso != null && classificacao != null) ...[
          Text(
            tipoCurso!,
            style: GoogleFonts.poppins(
              color: const Color(0xFFD1D5DB),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classificacao!,
            style: GoogleFonts.poppins(
              color: const Color(0xFFD1D5DB),
              fontSize: 15,
            ),
          ),
        ]
        // Se apenas subtitle for fornecido (modo compatibilidade)
        else if (subtitle != null)
          Text(
            subtitle!,
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
              onPressed: () {
                context.go('/meu-fluxograma/$title');
              },
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

// Item customizado para o dropdown, com gradiente animado no hover/selecionado
class _SimpleDropdownItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  const _SimpleDropdownItem({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Substituir o Container/StatefulBuilder da dropbar por um widget animado que mantém o gradiente enquanto o dropdown está aberto
class _AnimatedGradientDropdownBar extends StatefulWidget {
  final Widget child;
  final Key? dropdownKey;
  const _AnimatedGradientDropdownBar({required this.child, this.dropdownKey});

  @override
  State<_AnimatedGradientDropdownBar> createState() =>
      _AnimatedGradientDropdownBarState();
}

class _AnimatedGradientDropdownBarState
    extends State<_AnimatedGradientDropdownBar>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDropdownOpen = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  void setDropdownOpen(bool open) {
    setState(() {
      _isDropdownOpen = open;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = _isHovered || _isDropdownOpen;
    if (shouldAnimate) {
      _controller.repeat();
    } else {
      _controller.reset();
      _controller.stop();
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final gradient = LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFFF3CA5)],
            begin: Alignment(-1 + 2 * t, 0),
            end: Alignment(1 + 2 * t, 0),
          );
          return Container(
            key: widget.dropdownKey,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              gradient: shouldAnimate ? gradient : null,
              color: shouldAnimate ? null : const Color(0xFF232136),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1.5,
              ),
            ),
            child: NotificationListener<DropdownOpenedNotification>(
              onNotification: (notification) {
                setDropdownOpen(notification.opened);
                return true;
              },
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// Notificação customizada para saber se o dropdown está aberto
class DropdownOpenedNotification extends Notification {
  final bool opened;
  DropdownOpenedNotification(this.opened);
}
