import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../data/curso_model.dart';
import '../../../../cache/shared_preferences_helper.dart';

class ProgressSummarySection extends StatelessWidget {
  final CursoModel? courseData;

  const ProgressSummarySection({
    super.key,
    required this.courseData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          // Credits Progress
          Expanded(
            child: _buildCreditsProgressCard(),
          ),
          const SizedBox(width: 24),

          // Current Semester
          Expanded(
            child: _buildCurrentSemesterCard(),
          ),
          const SizedBox(width: 24),

          // Recommendations
          Expanded(
            child: _buildRecommendationsCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsProgressCard() {
    // Calculate credits progress
    final obrigatorias = courseData?.totalCreditos ?? 160;
    final optativas = courseData?.totalCreditos ?? 24;
    final livre = courseData?.totalCreditos ?? 24;

    int currentObrigatorias = 0;
    int currentOptativas = 0;
    int currentLivre = 0;

    final totalCurrent = currentObrigatorias + currentOptativas + currentLivre;
    final totalRequired = obrigatorias + optativas + livre;

    return _buildProgressCard(
      'Progresso de Créditos',
      Icons.school,
      const Color(0xFF8B5CF6),
      [
        {
          'label': 'Obrigatórias',
          'progress':
              totalRequired > 0 ? currentObrigatorias / obrigatorias : 0.0,
          'current': currentObrigatorias,
          'total': obrigatorias
        },
        {
          'label': 'Optativas',
          'progress': optativas > 0 ? currentOptativas / optativas : 0.0,
          'current': currentOptativas,
          'total': optativas
        },
        {
          'label': 'Módulo Livre',
          'progress': livre > 0 ? currentLivre / livre : 0.0,
          'current': currentLivre,
          'total': livre
        },
        {
          'label': 'Total',
          'progress': totalRequired > 0 ? totalCurrent / totalRequired : 0.0,
          'current': totalCurrent,
          'total': totalRequired,
          'isTotal': true
        },
      ],
    );
  }

  Widget _buildCurrentSemesterCard() {
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

    return Container(
      padding: const EdgeInsets.all(24),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Total de Matérias', '${currentSubjects.length}'),
          _buildInfoRow('Créditos', '$currentCredits'),
          _buildInfoRow('Carga Horária Semanal',
              '${(currentCredits * 2.5).round()} horas'),
          const SizedBox(height: 16),
          Text(
            'Próximo Semestre',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Matérias Selecionadas', '$selectedSubjects'),
          _buildInfoRow('Créditos Planejados', '$plannedCredits'),
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

    return Container(
      padding: const EdgeInsets.all(24),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...recommendations.map((rec) =>
              _buildRecommendationItem(rec['title']!, rec['description']!)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/assistente'),
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
              label: Text(
                'VER ASSISTENTE DE IA',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, IconData icon, Color color,
      List<Map<String, dynamic>> progressItems) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...progressItems.map((item) => _buildProgressItem(item)),
        ],
      ),
    );
  }

  Widget _buildProgressItem(Map<String, dynamic> item) {
    final isTotal = item['isTotal'] ?? false;
    final height = isTotal ? 12.0 : 10.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['label'],
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '${item['current']}/${item['total']} créditos',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item['progress'],
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTotal
                        ? [const Color(0xFFEC4899), const Color(0xFFDB2777)]
                        : [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
