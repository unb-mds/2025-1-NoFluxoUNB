import 'package:flutter/material.dart';
import 'package:mobile_app/config/size_config.dart';
import 'package:mobile_app/config/app_colors.dart';
import 'package:mobile_app/screens/fluxogramas/data/materia_model.dart';

class MateriaDataDialogContent extends StatefulWidget {
  const MateriaDataDialogContent({
    super.key,
    required this.materia,
    this.isAnonymous = false,
  });

  final MateriaModel materia;
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
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header com gradiente
          Container(
            padding: const EdgeInsets.all(24),
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
                          fontSize: getProportionateFontSize(24),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                          fontSize: getProportionateFontSize(12),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Departamento de Ciência da Computação",
                  style: TextStyle(
                    fontSize: getProportionateFontSize(14),
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
              controller: _tabController,
              indicatorColor: const Color(0xFFE11D48),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(
                fontSize: getProportionateFontSize(14),
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
              padding: const EdgeInsets.all(24),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInformationTab(),
                  _buildPrerequisitesTab(),
                  _buildEquivalenciesTab(),
                ],
              ),
            ),
          ),

          // Action Buttons\
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF374151),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "FECHAR",
                    style: TextStyle(
                      fontSize: getProportionateFontSize(14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Only show "Add to next semester" button for logged-in users
                if (!widget.isAnonymous) ...[
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFE11D48)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Implementar ação de adicionar ao próximo semestre
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "ADICIONAR AO PRÓXIMO SEMESTRE",
                        style: TextStyle(
                          fontSize: getProportionateFontSize(14),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }

  Widget _buildInformationTab() {
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
                fontSize: getProportionateFontSize(14),
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

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
              const SizedBox(width: 16),
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

          const SizedBox(height: 16),

          // Professores (se disponível)
          if (widget.materia.professor != null) ...[
            _buildInfoCard(
              title: "Professor",
              child: Text(
                widget.materia.professor!,
                style: TextStyle(
                  fontSize: getProportionateFontSize(14),
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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

  Widget _buildPrerequisitesTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: "Pré-requisitos Obrigatórios",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var prerequisito in widget.materia.prerequisitos)
                  _buildPrerequisiteItem(
                      prerequisito.codigoMateria,
                      prerequisito.nomeMateria,
                      prerequisito.status == 'completed',
                      prerequisito.status == 'current'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: "Correquisitos",
            child: Text(
              "Nenhum correquisito para esta disciplina.",
              style: TextStyle(
                fontSize: getProportionateFontSize(14),
                color: Colors.white.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquivalenciesTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: "Disciplinas Equivalentes",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEquivalencyItem("CIC0097", "Bancos de Dados", "Atual"),
                _buildEquivalencyItem(
                    "CIC0120", "Sistemas de Banco de Dados", "Antiga"),
                _buildEquivalencyItem(
                    "INF0110", "Banco de Dados I", "Outro Curso"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: "Observações",
            child: Text(
              "Esta disciplina substitui as antigas CIC0120 e INF0110. Alunos que cursaram essas disciplinas não precisam cursar CIC0097.",
              style: TextStyle(
                fontSize: getProportionateFontSize(14),
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
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
          const SizedBox(height: 8),
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
          const SizedBox(width: 12),
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
