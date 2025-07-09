import 'package:flutter/material.dart';
import '../../data/curso_model.dart';
import '../../data/materia_model.dart';
import '../../data/prerequisite_tree_model.dart';
import 'course_card_widget.dart';

/// Widget that handles visual prerequisite connections between course cards
class PrerequisiteConnectionsWidget extends StatefulWidget {
  final CursoModel? courseData;
  final double zoomLevel;
  final String? selectedSubjectCode;
  final bool isAnonymous;
  final Function(String?) onSubjectSelectionChanged;
  final Function(BuildContext, MateriaModel) onShowMateriaDialog;

  const PrerequisiteConnectionsWidget({
    super.key,
    required this.courseData,
    required this.zoomLevel,
    required this.selectedSubjectCode,
    required this.onSubjectSelectionChanged,
    required this.onShowMateriaDialog,
    this.isAnonymous = false,
  });

  @override
  State<PrerequisiteConnectionsWidget> createState() =>
      _PrerequisiteConnectionsWidgetState();
}

class _PrerequisiteConnectionsWidgetState
    extends State<PrerequisiteConnectionsWidget> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  Map<String, GlobalKey> _cardKeys = {};
  Map<String, List<String>> _subjectDependents = {};
  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    _buildDependentsMap();
  }

  @override
  void didUpdateWidget(PrerequisiteConnectionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseData != widget.courseData) {
      _buildDependentsMap();
    }
    if (oldWidget.selectedSubjectCode != widget.selectedSubjectCode) {
      if (widget.selectedSubjectCode != null) {
        _scaleController.forward();
      } else {
        _scaleController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _buildDependentsMap() {
    _subjectDependents.clear();
    _cardKeys.clear();

    if (widget.courseData == null) return;

    final tree = widget.courseData!.buildPrerequisiteTree();
    for (final node in tree.nodes.values) {
      final subjectCode = node.materia.codigoMateria;
      _cardKeys[subjectCode] = GlobalKey();

      // Build prerequisite chain instead of all dependents
      _subjectDependents[subjectCode] = _buildPrerequisiteChain(node, tree);
    }
  }

  /// Build a sequential chain of courses that follow this one as prerequisites
  List<String> _buildPrerequisiteChain(
      PrerequisiteTreeNode startNode, PrerequisiteTree tree) {
    List<String> chain = [];
    Set<String> visited = {startNode.materia.codigoMateria};

    PrerequisiteTreeNode? currentNode = startNode;

    while (currentNode != null && chain.length < 10) {
      // Find the next course in the chain (a course that has this one as a direct prerequisite)
      PrerequisiteTreeNode? nextNode;
      int minSemesterDiff = 999;

      // Look for unvisited dependents
      for (final dependent in currentNode.dependents) {
        if (!visited.contains(dependent.materia.codigoMateria)) {
          int semesterDiff =
              dependent.materia.nivel - currentNode.materia.nivel;

          // Prefer courses in future semesters, but accept any if none found
          if (semesterDiff > 0) {
            if (semesterDiff < minSemesterDiff) {
              nextNode = dependent;
              minSemesterDiff = semesterDiff;
            }
          } else if (nextNode == null) {
            // Accept any unvisited dependent if no future semester candidate found
            nextNode = dependent;
          }
        }
      }

      if (nextNode != null &&
          !visited.contains(nextNode.materia.codigoMateria)) {
        visited.add(nextNode.materia.codigoMateria);
        chain.add(nextNode.materia.codigoMateria);
        currentNode = nextNode;
      } else {
        break;
      }
    }

    return chain;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.courseData == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Stack(
        key: _stackKey,
        clipBehavior: Clip.none,
        children: [
          // Course cards layer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int semester = 1;
                  semester <= (widget.courseData?.semestres ?? 0);
                  semester++)
                _buildSemesterColumn(semester),
            ],
          ),

          // Connection lines layer - positioned on top
          if (widget.selectedSubjectCode != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Builder(
                  builder: (builderContext) => CustomPaint(
                    painter: PrerequisiteConnectionsPainter(
                      selectedSubjectCode: widget.selectedSubjectCode!,
                      dependents:
                          _subjectDependents[widget.selectedSubjectCode!] ?? [],
                      cardKeys: _cardKeys,
                      zoomLevel: widget.zoomLevel,
                      stackKey: _stackKey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterColumn(int semester) {
    return Container(
      margin: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          // Semester Header
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${semester}º Semestre',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          // Course Cards
          ..._getCoursesForSemester(semester),
        ],
      ),
    );
  }

  List<Widget> _getCoursesForSemester(int semester) {
    final subjects = widget.courseData?.materias
            .where((materia) => materia.nivel == semester)
            .toList() ??
        [];

    return subjects.map((subject) => _buildCourseCard(subject)).toList();
  }

  Widget _buildCourseCard(MateriaModel subject) {
    final subjectCode = subject.codigoMateria;
    final isSelected = widget.selectedSubjectCode == subjectCode;
    final isConnected = widget.selectedSubjectCode != null &&
        (_subjectDependents[widget.selectedSubjectCode!]
                    ?.contains(subjectCode) ==
                true ||
            _subjectDependents[subjectCode]
                    ?.contains(widget.selectedSubjectCode!) ==
                true);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        double scale = 1.0;
        if (isSelected) {
          scale = _scaleAnimation.value;
        } else if (isConnected) {
          scale = 1.05;
        }

        return Transform.scale(
          scale: scale,
          child: Container(
            key: _cardKeys[subjectCode],
            child: GestureDetector(
              onTap: () {
                if (widget.selectedSubjectCode == subjectCode) {
                  // Deselect if already selected
                  widget.onSubjectSelectionChanged(null);
                } else {
                  // Select new subject
                  widget.onSubjectSelectionChanged(subjectCode);
                }
                widget.onShowMateriaDialog(context, subject);
              },
              onLongPress: () {
                if (widget.selectedSubjectCode == subjectCode) {
                  widget.onSubjectSelectionChanged(null);
                } else {
                  widget.onSubjectSelectionChanged(subjectCode);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected || isConnected
                      ? [
                          BoxShadow(
                            color: isSelected
                                ? Colors.orange.withOpacity(0.5)
                                : Colors.blue.withOpacity(0.3),
                            blurRadius: isSelected ? 12 : 8,
                            offset: const Offset(0, 4),
                            spreadRadius: isSelected ? 2 : 1,
                          ),
                        ]
                      : null,
                ),
                child: EnhancedCourseCardWidget(
                  subject: subject,
                  isHighlighted: isConnected,
                  isSelected: isSelected,
                  onTap: () {
                    widget.onShowMateriaDialog(context, subject);
                  },
                  isAnonymous: widget.isAnonymous,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for drawing prerequisite connections
class PrerequisiteConnectionsPainter extends CustomPainter {
  final String selectedSubjectCode;
  final List<String> dependents;
  final Map<String, GlobalKey> cardKeys;
  final double zoomLevel;
  final GlobalKey stackKey;

  PrerequisiteConnectionsPainter({
    required this.selectedSubjectCode,
    required this.dependents,
    required this.cardKeys,
    required this.zoomLevel,
    required this.stackKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dependents.isEmpty) return;

    final selectedCardKey = cardKeys[selectedSubjectCode];
    if (selectedCardKey?.currentContext == null) return;

    final selectedRenderBox =
        selectedCardKey!.currentContext!.findRenderObject() as RenderBox?;
    if (selectedRenderBox == null) return;

    // Get the render box of the Stack to convert coordinates
    final stackRenderBox =
        stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackRenderBox == null) {
      return _paintWithGlobalCoordinates(canvas, size);
    }

    // Convert positions to local coordinates relative to the Stack
    final selectedLocalPosition = stackRenderBox
        .globalToLocal(selectedRenderBox.localToGlobal(Offset.zero));
    final selectedSize = selectedRenderBox.size;
    final selectedCenter = Offset(
      selectedLocalPosition.dx + selectedSize.width / 2,
      selectedLocalPosition.dy + selectedSize.height / 2,
    );

    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2.5 * zoomLevel
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..strokeWidth = 6 * zoomLevel
      ..style = PaintingStyle.stroke;

    // Draw sequential chain: selected -> first -> second -> third...
    List<String> chainCodes = [selectedSubjectCode] + dependents;

    for (int i = 0; i < chainCodes.length - 1; i++) {
      final fromCode = chainCodes[i];
      final toCode = chainCodes[i + 1];

      final fromCardKey = cardKeys[fromCode];
      final toCardKey = cardKeys[toCode];

      if (fromCardKey?.currentContext == null ||
          toCardKey?.currentContext == null) continue;

      final fromRenderBox =
          fromCardKey!.currentContext!.findRenderObject() as RenderBox?;
      final toRenderBox =
          toCardKey!.currentContext!.findRenderObject() as RenderBox?;

      if (fromRenderBox == null || toRenderBox == null) continue;

      // Convert positions to local coordinates relative to the Stack
      final fromLocalPosition = stackRenderBox
          .globalToLocal(fromRenderBox.localToGlobal(Offset.zero));
      final fromSize = fromRenderBox.size;
      final fromCenter = Offset(
        fromLocalPosition.dx + fromSize.width / 2,
        fromLocalPosition.dy + fromSize.height / 2,
      );

      final toLocalPosition =
          stackRenderBox.globalToLocal(toRenderBox.localToGlobal(Offset.zero));
      final toSize = toRenderBox.size;
      final toCenter = Offset(
        toLocalPosition.dx + toSize.width / 2,
        toLocalPosition.dy + toSize.height / 2,
      );

      // Draw curved connection line
      final controlPoint1 = Offset(
        fromCenter.dx + (toCenter.dx - fromCenter.dx) * 0.3,
        fromCenter.dy - 50 * zoomLevel,
      );
      final controlPoint2 = Offset(
        fromCenter.dx + (toCenter.dx - fromCenter.dx) * 0.7,
        toCenter.dy - 50 * zoomLevel,
      );

      final path = Path()
        ..moveTo(fromCenter.dx, fromCenter.dy)
        ..cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          toCenter.dx,
          toCenter.dy,
        );

      // Draw glow effect
      canvas.drawPath(path, glowPaint);

      // Draw main line
      canvas.drawPath(path, paint);

      // Draw arrow at the end
      _drawArrow(canvas, controlPoint2, toCenter, paint);
    }
  }

  // Fallback method using global coordinates (if context is not available)
  void _paintWithGlobalCoordinates(Canvas canvas, Size size) {
    final selectedCardKey = cardKeys[selectedSubjectCode];
    if (selectedCardKey?.currentContext == null) return;

    final selectedRenderBox =
        selectedCardKey!.currentContext!.findRenderObject() as RenderBox?;
    if (selectedRenderBox == null) return;

    final selectedPosition = selectedRenderBox.localToGlobal(Offset.zero);
    final selectedSize = selectedRenderBox.size;
    final selectedCenter = Offset(
      selectedPosition.dx + selectedSize.width / 2,
      selectedPosition.dy + selectedSize.height / 2,
    );

    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2.5 * zoomLevel
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..strokeWidth = 6 * zoomLevel
      ..style = PaintingStyle.stroke;

    // Draw sequential chain: selected -> first -> second -> third...
    List<String> chainCodes = [selectedSubjectCode] + dependents;

    for (int i = 0; i < chainCodes.length - 1; i++) {
      final fromCode = chainCodes[i];
      final toCode = chainCodes[i + 1];

      final fromCardKey = cardKeys[fromCode];
      final toCardKey = cardKeys[toCode];

      if (fromCardKey?.currentContext == null ||
          toCardKey?.currentContext == null) continue;

      final fromRenderBox =
          fromCardKey!.currentContext!.findRenderObject() as RenderBox?;
      final toRenderBox =
          toCardKey!.currentContext!.findRenderObject() as RenderBox?;

      if (fromRenderBox == null || toRenderBox == null) continue;

      final fromPosition = fromRenderBox.localToGlobal(Offset.zero);
      final fromSize = fromRenderBox.size;
      final fromCenter = Offset(
        fromPosition.dx + fromSize.width / 2,
        fromPosition.dy + fromSize.height / 2,
      );

      final toPosition = toRenderBox.localToGlobal(Offset.zero);
      final toSize = toRenderBox.size;
      final toCenter = Offset(
        toPosition.dx + toSize.width / 2,
        toPosition.dy + toSize.height / 2,
      );

      // Draw curved connection line
      final controlPoint1 = Offset(
        fromCenter.dx + (toCenter.dx - fromCenter.dx) * 0.3,
        fromCenter.dy - 50 * zoomLevel,
      );
      final controlPoint2 = Offset(
        fromCenter.dx + (toCenter.dx - fromCenter.dx) * 0.7,
        toCenter.dy - 50 * zoomLevel,
      );

      final path = Path()
        ..moveTo(fromCenter.dx, fromCenter.dy)
        ..cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          toCenter.dx,
          toCenter.dy,
        );

      // Draw glow effect
      canvas.drawPath(path, glowPaint);

      // Draw main line
      canvas.drawPath(path, paint);

      // Draw arrow at the end
      _drawArrow(canvas, controlPoint2, toCenter, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final arrowLength = 15 * zoomLevel;
    final arrowAngle = 0.3;

    final direction = (end - start);
    final magnitude = direction.distance;
    if (magnitude == 0) return;

    final unitDirection = direction / magnitude;

    final arrowPoint1 = end -
        Offset(
          unitDirection.dx * arrowLength -
              unitDirection.dy * arrowLength * arrowAngle,
          unitDirection.dy * arrowLength +
              unitDirection.dx * arrowLength * arrowAngle,
        );

    final arrowPoint2 = end -
        Offset(
          unitDirection.dx * arrowLength +
              unitDirection.dy * arrowLength * arrowAngle,
          unitDirection.dy * arrowLength -
              unitDirection.dx * arrowLength * arrowAngle,
        );

    final arrowPath = Path()
      ..moveTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(PrerequisiteConnectionsPainter oldDelegate) {
    return selectedSubjectCode != oldDelegate.selectedSubjectCode ||
        dependents != oldDelegate.dependents ||
        zoomLevel != oldDelegate.zoomLevel;
  }
}

/// Enhanced course card widget with highlighting support
class EnhancedCourseCardWidget extends StatelessWidget {
  final MateriaModel subject;
  final bool isHighlighted;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isAnonymous;

  const EnhancedCourseCardWidget({
    super.key,
    required this.subject,
    this.isHighlighted = false,
    this.isSelected = false,
    this.onTap,
    this.isAnonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: Colors.orange, width: 2)
            : isHighlighted
                ? Border.all(color: Colors.blue, width: 1.5)
                : null,
      ),
      child: CourseCardWidget(
        subject: subject,
        onTap: onTap,
        isAnonymous: isAnonymous,
      ),
    );
  }
}
