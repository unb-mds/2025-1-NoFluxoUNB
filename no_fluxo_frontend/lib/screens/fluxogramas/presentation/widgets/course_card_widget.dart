import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/materia_model.dart';
import '../../../../config/app_colors.dart';

class CourseCardWidget extends StatelessWidget {
  final MateriaModel subject;
  final VoidCallback? onTap;

  const CourseCardWidget({
    super.key,
    required this.subject,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color startColor;
    Color endColor;

    switch (subject.status) {
      case 'completed':
        startColor = AppColors.completedStart;
        endColor = AppColors.completedEnd;
        break;
      case 'current':
        startColor = AppColors.currentStart;
        endColor = AppColors.currentEnd;
        break;
      case 'selected':
        startColor = AppColors.selectedStart;
        endColor = AppColors.selectedEnd;
        break;
      case 'optative':
        startColor = AppColors.optativeStart;
        endColor = AppColors.optativeEnd;
        break;
      default: // future
        startColor = AppColors.futureStart;
        endColor = AppColors.futureEnd;
    }

    return Container(
      width: 192,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: subject.status == 'completed'
            ? AppColors.completedBackground
            : subject.status == 'current'
                ? AppColors.currentBackground
                : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.codigoMateria,
                  style: GoogleFonts.poppins(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject.nomeMateria,
                  style: GoogleFonts.poppins(
                    color: AppColors.white,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.containerBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${subject.creditos} créditos',
                        style: GoogleFonts.poppins(
                          color: AppColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (subject.mencao != null && subject.mencao != '-') ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.containerBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subject.mencao ?? 'Sem Mencao',
                          style: GoogleFonts.poppins(
                            color: AppColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
