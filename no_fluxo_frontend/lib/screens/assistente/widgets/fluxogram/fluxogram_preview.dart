import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class FluxogramPreview extends StatelessWidget {
  const FluxogramPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu Fluxograma',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Fluxogram SVG Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 300),
              painter: FluxogramPainter(),
            ),
          ),

          const SizedBox(height: 16),

          // View Full Fluxogram Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.go('/fluxogramas');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Text(
                'VER FLUXOGRAMA COMPLETO',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FluxogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Semester headers
    _drawText(canvas, '1º Semestre', Offset(50, 20), textPainter, 12);
    _drawText(canvas, '2º Semestre', Offset(50, 90), textPainter, 12);
    _drawText(canvas, '3º Semestre', Offset(50, 160), textPainter, 12);
    _drawText(canvas, '4º Semestre', Offset(50, 230), textPainter, 12);

    // Semester 1 - Completed (Green)
    _drawCourseBox(canvas, Offset(20, 30), 'Algoritmos', Colors.green);
    _drawCourseBox(canvas, Offset(110, 30), 'Cálculo 1', Colors.green);
    _drawCourseBox(canvas, Offset(200, 30), 'APC', Colors.green);
    _drawCourseBox(canvas, Offset(290, 30), 'Introdução ES', Colors.green);

    // Semester 2 - Completed (Green)
    _drawCourseBox(canvas, Offset(20, 100), 'EDA', Colors.green);
    _drawCourseBox(canvas, Offset(110, 100), 'Cálculo 2', Colors.green);
    _drawCourseBox(canvas, Offset(200, 100), 'OO', Colors.green);
    _drawCourseBox(canvas, Offset(290, 100), 'Requisitos', Colors.green);

    // Semester 3 - Current (Purple)
    _drawCourseBox(canvas, Offset(20, 170), 'Projeto 1', Colors.purple);
    _drawCourseBox(canvas, Offset(110, 170), 'Métodos', Colors.purple);
    _drawCourseBox(canvas, Offset(200, 170), 'Arquitetura', Colors.purple);
    _drawCourseBox(canvas, Offset(290, 170), 'Bancos de Dados', Colors.pink);

    // Semester 4 - Future (Gray)
    _drawCourseBox(canvas, Offset(20, 240), 'Projeto 2', Colors.grey,
        isFuture: true);
    _drawCourseBox(canvas, Offset(110, 240), 'Qualidade', Colors.grey,
        isFuture: true);
    _drawCourseBox(canvas, Offset(200, 240), 'Testes', Colors.grey,
        isFuture: true);
    _drawCourseBox(canvas, Offset(290, 240), 'GPP', Colors.grey,
        isFuture: true);

    // Connection lines
    _drawConnectionLine(canvas, Offset(60, 70), Offset(60, 100));
    _drawConnectionLine(canvas, Offset(150, 70), Offset(150, 100));
    _drawConnectionLine(canvas, Offset(240, 70), Offset(240, 100));
    _drawConnectionLine(canvas, Offset(330, 70), Offset(330, 100));

    _drawConnectionLine(canvas, Offset(60, 140), Offset(60, 170));
    _drawConnectionLine(canvas, Offset(150, 140), Offset(150, 170));
    _drawConnectionLine(canvas, Offset(240, 140), Offset(240, 170));
    _drawConnectionLine(canvas, Offset(330, 140), Offset(330, 170));

    _drawConnectionLine(canvas, Offset(60, 210), Offset(60, 240));
    _drawConnectionLine(canvas, Offset(150, 210), Offset(150, 240));
    _drawConnectionLine(canvas, Offset(240, 210), Offset(240, 240));
    _drawConnectionLine(canvas, Offset(330, 210), Offset(330, 240));
  }

  void _drawCourseBox(Canvas canvas, Offset position, String text, Color color,
      {bool isFuture = false}) {
    final rect = Rect.fromLTWH(position.dx, position.dy, 80, 40);

    if (isFuture) {
      // Future courses with border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = Colors.grey.withOpacity(0.4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        borderPaint,
      );
    } else {
      // Current/completed courses
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = color.withOpacity(0.8),
      );
    }

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx + (80 - textPainter.width) / 2,
        position.dy + (40 - textPainter.height) / 2,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset position,
      TextPainter textPainter, double fontSize) {
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawConnectionLine(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
