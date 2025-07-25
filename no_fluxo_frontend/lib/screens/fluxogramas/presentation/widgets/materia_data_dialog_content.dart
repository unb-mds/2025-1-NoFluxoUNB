import 'package:flutter/material.dart';
import 'package:mobile_app/config/size_config.dart';
import 'package:mobile_app/config/app_colors.dart';
import 'package:mobile_app/screens/fluxogramas/data/materia_model.dart';
import 'package:mobile_app/screens/fluxogramas/data/curso_model.dart'; // Added import for CursoModel

class MateriaDataDialogContent extends StatefulWidget {
  const MateriaDataDialogContent({
    super.key,
    required this.materia,
    required this.curso, // NOVO
    this.isAnonymous = false,
  });

  final MateriaModel materia;
  final CursoModel curso; // NOVO
  final bool isAnonymous;

  @override
  State<MateriaDataDialogContent> createState() =>
      _MateriaDataDialogContentState();
}

class _MateriaDataDialogContentState extends State<MateriaDataDialogContent>
    with TickerProviderStateMixin {
  String? errorFound;
  bool loaded = false;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    // For anonymous users, don't show current/selected status
    String status = widget.materia.status?.toLowerCase() ?? '';
    if (widget.isAnonymous &&
        (status == 'em_curso' || status == 'selecionada')) {
      return Colors.white.withOpacity(0.1);
    }

    switch (status) {
      case 'concluida':
      case 'completed':
        return const Color(0xFF22C55E);
      case 'em_curso':
      case 'current':
        return widget.isAnonymous
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFF8B5CF6);
      case 'selecionada':
      case 'selected':
        return widget.isAnonymous
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFE11D48);
      default:
        return Colors.white.withOpacity(0.1);
    }
  }

  String _getStatusText() {
    // For anonymous users, don't show current/selected status
    String status = widget.materia.status?.toLowerCase() ?? '';
    if (widget.isAnonymous &&
        (status == 'em_curso' || status == 'selecionada')) {
      return 'Disponível';
    }

    switch (status) {
      case 'concluida':
      case 'completed':
        return 'Concluída';
      case 'em_curso':
      case 'current':
        return widget.isAnonymous ? 'Disponível' : 'Em Curso';
      case 'selecionada':
      case 'selected':
        return widget.isAnonymous ? 'Disponível' : 'Selecionada';
      default:
        return 'Disponível';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsividade
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    // ALTERAÇÃO: largura do modal = 90% da tela em mobile/tablet, 900px no desktop
    final modalWidth = (isMobile || isTablet) ? screenWidth * 0.9 : 900.0;
    final dialogPadding = isMobile ? 2.0 : 24.0;
    final headerFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final tabFontSize = isMobile ? 12.0 : 14.0;
    final infoFontSize = isMobile ? 12.0 : 14.0;
    final buttonFontSize = isMobile ? 12.0 : 14.0;
    final buttonPaddingH = isMobile ? 12.0 : 20.0;
    final buttonPaddingV = isMobile ? 8.0 : 12.0;
    final buttonText = modalWidth < 350 ? "ADICIONAR" : "ADICIONAR AO PRÓXIMO SEMESTRE";

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: modalWidth,
          maxHeight: screenWidth < 700 ? MediaQuery.of(context).size.height * 0.98 : 700,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header com gradiente
                Container(
                  padding: EdgeInsets.all(dialogPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4A1D96).withOpacity(0.8),
                        const Color(0xFFE11D48).withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${widget.materia.codigoMateria} - ${widget.materia.nomeMateria}",
                              style: TextStyle(
                                fontSize: headerFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: isMobile ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor().withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: tabFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      Text(
                        "Departamento de Ciência da Computação",
                        style: TextStyle(
                          fontSize: infoFontSize,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF374151),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    indicatorColor: const Color(0xFFE11D48),
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    labelStyle: TextStyle(
                      fontSize: tabFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: "Informações"),
                      Tab(text: "Pré-requisitos"),
                      Tab(text: "Equivalências"),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(dialogPadding),
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _tabController,
                      children: [
                        _buildInformationTab(infoFontSize, isMobile),
                        _buildPrerequisitesTab(infoFontSize, isMobile),
                        _buildEquivalenciesTab(infoFontSize, isMobile),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.all(dialogPadding),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: buttonPaddingH,
                              vertical: buttonPaddingV,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "FECHAR",
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      if (!widget.isAnonymous) ...[
                        SizedBox(width: isMobile ? 8 : 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFE11D48)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Matéria adicionada ao próximo semestre!"),
                                    backgroundColor: Color(0xFF22C55E),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(
                                  horizontal: buttonPaddingH,
                                  vertical: buttonPaddingV,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                buttonText,
                                style: TextStyle(
                                  fontSize: buttonFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.visible,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformationTab(double fontSize, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descrição
          _buildInfoCard(
            title: "Descrição",
            child: Text(
              widget.materia.ementa.isNotEmpty
                  ? widget.materia.ementa
                  : "Informações sobre banco de dados, modelagem, linguagens de definição e manipulação de dados, projeto de banco de dados, armazenamento e indexação.",
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),

          SizedBox(height: 16),

          // Grid com informações básicas
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: "Créditos",
                  child: Text(
                    "${widget.materia.creditos} (${widget.materia.creditos * 15} horas)",
                    style: TextStyle(
                      fontSize: getProportionateFontSize(16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  title: "Período Ideal",
                  child: Text(
                    "${widget.materia.nivel}º Semestre",
                    style: TextStyle(
                      fontSize: getProportionateFontSize(16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Professores (se disponível)
          if (widget.materia.professor != null) ...[
            _buildInfoCard(
              title: "Professor",
              child: Text(
                widget.materia.professor!,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          // Menção (se disponível) - only for logged-in users
          if (!widget.isAnonymous && widget.materia.mencao != null) ...[
            _buildInfoCard(
              title: "Menção Obtida",
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getMencaoColor(widget.materia.mencao!),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.materia.mencao!,
                  style: TextStyle(
                    fontSize: getProportionateFontSize(14),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          /*  // Horários disponíveis (exemplo)
          _buildInfoCard(
            title: "Horários Disponíveis",
            child: Column(
              children: [
                _buildScheduleCard("Turma A", "Terça e Quinta, 10:00 - 11:50"),
                const SizedBox(height: 8),
                _buildScheduleCard(
                    "Turma B", "Segunda e Quarta, 14:00 - 15:50"),
              ],
            ),
          ), */
        ],
      ),
    );
  }

  Widget _buildPrerequisitesTab(double fontSize, bool isMobile) {
    return SingleChildScrollView(
      child: Builder(builder: (context) {
        var materiasPorNivel = <int, List<MateriaModel>>{};

        for (var materia in widget.materia.preRequisitos) {
          if (!materiasPorNivel.containsKey(materia.nivel)) {
            materiasPorNivel[materia.nivel] = [];
          }
          materiasPorNivel[materia.nivel]!.add(materia);
        }

        var materiasPorNivelList = materiasPorNivel.keys.toList()
          ..sort((a, b) => a.compareTo(b));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              title: "Pré-requisitos Obrigatórios",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var nivel in materiasPorNivelList) ...[
                    Text(
                      "Nível $nivel",
                      style: TextStyle(
                        fontSize: getProportionateFontSize(16),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    for (var prerequisito in materiasPorNivel[nivel]!
                      ..sort(
                          (a, b) => a.codigoMateria.compareTo(b.codigoMateria)))
                      _buildPrerequisiteItem(
                          prerequisito.codigoMateria,
                          prerequisito.nomeMateria,
                          prerequisito.status == 'completed',
                          prerequisito.status == 'current'),
                  ]
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              title: "Correquisitos",
              child: Builder(
                builder: (context) {
                  final coreqs = widget.curso.coRequisitos
                      .where((c) => c.idMateria == widget.materia.idMateria)
                      .toList();
                  if (coreqs.isEmpty) {
                    return Text(
                      "Nenhum correquisito para esta disciplina.",
                      style: TextStyle(
                        fontSize: getProportionateFontSize(14),
                        color: Colors.white.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: coreqs.map((c) {
                        final materiaCoreq = widget.curso.materias.firstWhere(
                          (m) => m.codigoMateria == c.codigoMateriaCoRequisito,
                          orElse: () => MateriaModel(
                            ementa: '',
                            idMateria: 0,
                            nomeMateria: c.nomeMateriaCoRequisito,
                            codigoMateria: c.codigoMateriaCoRequisito,
                            nivel: 0,
                            creditos: 0,
                          ),
                        );
                        if (materiaCoreq == null) {
                          return Text(
                            "${c.codigoMateriaCoRequisito} - ${c.nomeMateriaCoRequisito}",
                            style: TextStyle(
                              fontSize: getProportionateFontSize(14),
                              color: Colors.white,
                            ),
                          );
                        }
                        return Row(
                          children: [
                            Icon(
                              materiaCoreq.status == 'completed'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: materiaCoreq.status == 'completed'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "${materiaCoreq.codigoMateria} - ${materiaCoreq.nomeMateria} (Nível ${materiaCoreq.nivel})",
                                style: TextStyle(
                                  fontSize: getProportionateFontSize(14),
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  }
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEquivalenciesTab(double fontSize, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: "Disciplinas Equivalentes",
            child: Builder(
              builder: (context) {
                final equivalencias = widget.curso.equivalencias
                    .where((e) =>
                        e.codigoMateriaOrigem == widget.materia.codigoMateria)
                    .toList();
                if (equivalencias.isEmpty) {
                  return Text(
                    "Nenhuma equivalência cadastrada para esta disciplina.",
                    style: TextStyle(
                      fontSize: getProportionateFontSize(14),
                      color: Colors.white.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: equivalencias.map((e) {
                      return Row(
                        children: [
                          Icon(Icons.compare_arrows,
                              color: Colors.amber, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${e.codigoMateriaEquivalente} - ${e.nomeMateriaEquivalente}",
                              style: TextStyle(
                                fontSize: getProportionateFontSize(14),
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: getProportionateFontSize(16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String turma, String horario) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turma,
                  style: TextStyle(
                    fontSize: getProportionateFontSize(14),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: getProportionateFontSize(12),
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisiteItem(
      String codigo, String nome, bool concluido, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isCurrent
                ? Icons.check_circle
                : concluido
                    ? Icons.check_circle
                    : Icons.cancel,
            color: isCurrent
                ? const Color(0xFF22C55E)
                : concluido
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "$codigo - $nome",
              style: TextStyle(
                fontSize: getProportionateFontSize(14),
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquivalencyItem(String codigo, String nome, String tipo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$codigo - $nome",
                  style: TextStyle(
                    fontSize: getProportionateFontSize(14),
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tipo,
              style: TextStyle(
                fontSize: getProportionateFontSize(12),
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMencaoColor(String mencao) {
    switch (mencao.toUpperCase()) {
      case 'SS':
        return const Color(0xFF10B981);
      case 'MS':
        return const Color(0xFF3B82F6);
      case 'MM':
        return const Color(0xFFF59E0B);
      case 'MI':
        return const Color(0xFFEF4444);
      case 'II':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF374151);
    }
  }
}
