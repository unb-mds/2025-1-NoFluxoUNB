import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../cache/shared_preferences_helper.dart';
import '../../data/materia_model.dart';
import '../../../../config/app_colors.dart';

class CourseCardWidget extends StatelessWidget {
  final MateriaModel subject;
  final VoidCallback? onTap;
  final bool isAnonymous;
  final List<MateriaModel>? allSubjects; // Para verificar pré-requisitos

  const CourseCardWidget({
    super.key,
    required this.subject,
    this.onTap,
    this.isAnonymous = false,
    this.allSubjects,
  });

  @override
  Widget build(BuildContext context) {
    Color startColor;
    Color endColor;

    // For anonymous users, only show completed, optative, and future statuses
    String displayStatus = subject.status ?? 'future';
    if (isAnonymous &&
        subject.status == 'current' &&
        SharedPreferencesHelper.isAnonimo) {
      displayStatus = 'future';
    }

    // Check if this subject can be taken (prerequisites completed)
    bool canBeTaken = _canSubjectBeTaken();

    switch (displayStatus) {
      case 'completed':
        startColor = AppColors.completedStart;
        endColor = AppColors.completedEnd;
        break;
      case "can_be_next":
        startColor = AppColors.readyStart;
        endColor = AppColors.readyEnd;
        break;
      case 'selected':
        if (isAnonymous && SharedPreferencesHelper.isAnonimo) {
          // For anonymous users, treat selected as future
          startColor = AppColors.futureStart;
          endColor = AppColors.futureEnd;
        } else {
          startColor = AppColors.selectedStart;
          endColor = AppColors.selectedEnd;
        }
        break;
      case 'current':
        startColor = AppColors.currentStart;
        endColor = AppColors.currentEnd;
        break;
      case 'optative':
        startColor = AppColors.optativeStart;
        endColor = AppColors.optativeEnd;
        break;
      default:
        // Check if prerequisites are completed for future subjects
        if (canBeTaken && displayStatus == 'future' && !isAnonymous) {
          startColor = AppColors.readyStart;
          endColor = AppColors.readyEnd;
        } else {
          startColor = AppColors.futureStart;
          endColor = AppColors.futureEnd;
        }
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
        color: displayStatus == 'completed'
            ? AppColors.completedBackground
            : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
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
                        // Only show mencao for non-anonymous users and when mencao exists
                        if (subject.mencao != null &&
                            subject.mencao != '-') ...[
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
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Verifica se a matéria será liberada após a conclusão das matérias em curso
  /// (simulação de conclusão das matérias roxas)
  bool _canSubjectBeTaken() {
    if (subject.status == 'completed' ||
        subject.status == 'current' ||
        subject.status == 'selected') {
      return false;
    }

    return !subject.hasAnyPrerequisitesNotCompletedOrCurrent();
  }
}
