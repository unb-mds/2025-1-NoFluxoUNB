import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../data/curso_model.dart';
import '../../../../cache/shared_preferences_helper.dart';

class ProgressSummarySection extends StatelessWidget {
  final CursoModel? courseData;
  final bool isAnonymous;

  const ProgressSummarySection({
    super.key,
    required this.courseData,
    this.isAnonymous = false,
  });

  // Função para obter dimensões responsivas
  double _getResponsiveFontSize(BuildContext context, {double baseSize = 16.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize * 0.8; // Mobile
    if (screenWidth < 900) return baseSize * 0.9; // Tablet
    return baseSize; // Desktop
  }

  double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 12.0; // Mobile
    if (screenWidth < 900) return 16.0; // Tablet
    return 24.0; // Desktop
  }

  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    if (screenWidth < 900) return 20.0; // Tablet
    return 24.0; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    // Don't show progress summary for anonymous users
    if (isAnonymous) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 24 : 32),
      child: isMobile 
          ? _buildMobileLayout(context, responsiveSpacing)
          : _buildDesktopLayout(context, responsiveSpacing),
    );
  }

  Widget _buildMobileLayout(BuildContext context, double spacing) {
    return Column(
      children: [
        // Credits Progress
        _buildCreditsProgressCard(context),
        SizedBox(height: spacing),

        // Current Semester
        _buildCurrentSemesterCard(context),
        SizedBox(height: spacing),

        // Recommendations
        _buildRecommendationsCard(context),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double spacing) {
    return Row(
      children: [
        // Credits Progress
        Expanded(
          child: _buildCreditsProgressCard(context),
        ),
        SizedBox(width: spacing),

        // Current Semester
        Expanded(
          child: _buildCurrentSemesterCard(context),
        ),
        SizedBox(width: spacing),

        // Recommendations
        Expanded(
          child: _buildRecommendationsCard(context),
        ),
      ],
    );
  }

  Widget _buildCreditsProgressCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school, 
                color: const Color(0xFF8B5CF6), 
                size: _getResponsiveFontSize(context, baseSize: 24)
              ),
              SizedBox(width: _getResponsiveSpacing(context) / 2),
              Expanded(
                child: Text(
                  'Progresso de Créditos',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(context, baseSize: 20),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: _getResponsiveSpacing(context) * 2),
          // Mensagem "Em breve"
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.construction,
                  color: const Color(0xFF8B5CF6),
                  size: _getResponsiveFontSize(context, baseSize: 48),
                ),
                SizedBox(height: _getResponsiveSpacing(context)),
                Text(
                  'Em breve',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(context, baseSize: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: _getResponsiveSpacing(context) / 2),
                Text(
                  'Funcionalidade em desenvolvimento',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: _getResponsiveFontSize(context, baseSize: 14),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: _getResponsiveSpacing(context) * 2),
        ],
      ),
    );
  }

  Widget _buildCurrentSemesterCard(BuildContext context) {
    final currentUser = SharedPreferencesHelper.currentUser;
    int currentSemester = 1;

    if (currentUser?.dadosFluxograma != null) {
      currentSemester = currentUser!.dadosFluxograma!.semestreAtual;
    }

    final currentSubjects = courseData?.materias
            .where((materia) => materia.nivel == currentSemester)
            .toList() ??
        [];
    final currentCredits =
        currentSubjects.fold<int>(0, (sum, subject) => sum + subject.creditos);

    final nextSemester = currentSemester + 1;
    final nextSubjects = courseData?.materias
            .where((materia) => materia.nivel == nextSemester)
            .toList() ??
        [];
    final selectedSubjects =
        nextSubjects.where((s) => s.status == 'selected').length;
    final plannedCredits = nextSubjects
        .where((s) => s.status == 'selected')
        .fold<int>(0, (sum, subject) => sum + subject.creditos);

    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semestre Atual: ${currentSemester}º',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsiveSpacing),
          _buildInfoRow(context, 'Total de Matérias', '${currentSubjects.length}'),
          _buildInfoRow(context, 'Créditos', '$currentCredits'),
          _buildInfoRow(context, 'Carga Horária Semanal',
              '${(currentCredits * 2.5).round()} horas'),
          SizedBox(height: responsiveSpacing),
          Text(
            'Próximo Semestre',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsiveSpacing / 2),
          _buildInfoRow(context, 'Matérias Selecionadas', '$selectedSubjects'),
          _buildInfoRow(context, 'Créditos Planejados', '$plannedCredits'),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context) {
    final recommendations = <Map<String, String>>[];

    recommendations.add({
      'title': 'Balanceamento de Carga',
      'description':
          'Considere adicionar mais 2-3 matérias para o próximo semestre para manter um ritmo adequado.',
    });

    recommendations.add({
      'title': 'Matérias Sugeridas',
      'description':
          'Com base no seu perfil, recomendamos consultar o assistente de IA para sugestões personalizadas.',
    });

    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recomendações',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsiveSpacing),
          ...recommendations.map((rec) =>
              _buildRecommendationItem(context, rec['title']!, rec['description']!)),
          SizedBox(height: responsiveSpacing),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/assistente'),
                icon: Icon(
                  Icons.psychology, 
                  color: Colors.white,
                  size: _getResponsiveFontSize(context, baseSize: 20),
                ),
                label: Text(
                  isMobile ? 'ASSISTENTE DE IA' : 'FALAR COM ASSISTENTE',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _getResponsiveFontSize(context, baseSize: 12),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 10 : 12,
                    horizontal: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: _getResponsiveFontSize(context, baseSize: 14),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 14),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(BuildContext context, String title, String description) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 14),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: _getResponsiveFontSize(context, baseSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
