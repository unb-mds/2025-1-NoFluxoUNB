import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GraffitiBackground extends StatelessWidget {
  const GraffitiBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Gradiente de fundo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9333EA), // Roxo
                  Color(0xFFE11D48), // Rosa
                  Color(0xFFEA580C), // Laranja
                  Color(0xFFCA8A04), // Amarelo
                  Color(0xFF000000), // Preto
                ],
                stops: [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
            ),
          ),
          // Brick wall overlay
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _BrickWallPainter(),
          ),
          // SVGs coloridos (formas e círculos)
          ..._graffitiSVGs(context),
        ],
      ),
    );
  }
}

// Brick wall painter
class _BrickWallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const brickWidth = 60.0;
    const brickHeight = 30.0;
    for (double y = 0; y < size.height; y += brickHeight) {
      final offset = ((y ~/ brickHeight) % 2 == 0) ? 0.0 : brickWidth / 2;
      for (double x = -brickWidth; x < size.width; x += brickWidth) {
        final left = x + offset;
        final right = left + brickWidth;
        final top = y;
        final bottom = y + brickHeight;
        // Retângulo
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// SVGs coloridos (formas e círculos)
List<Widget> _graffitiSVGs(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  final height = MediaQuery.of(context).size.height;
  return [
    // Exemplo de algumas formas, pode adicionar mais conforme o HTML
    Positioned(
      top: height * 0.38,
      left: width * 0.36,
      child: Opacity(
        opacity: 0.33,
        child: SvgPicture.string(
          '<svg width="50" height="100" viewBox="0 0 50 100"><path d="M25,0 Q20,28.34 25,56.68 Q30,28.34 25,0 Z" fill="#CA8A04"/></svg>',
        ),
      ),
    ),
    Positioned(
      top: height * 0.65,
      left: width * 0.22,
      child: Opacity(
        opacity: 0.32,
        child: SvgPicture.string(
          '<svg width="50" height="100" viewBox="0 0 50 100"><path d="M25,0 Q20,29.79 25,59.58 Q30,29.79 25,0 Z" fill="#E11D48"/></svg>',
        ),
      ),
    ),
    Positioned(
      top: height * 0.70,
      left: width * 0.62,
      child: Opacity(
        opacity: 0.30,
        child: SvgPicture.string(
          '<svg width="50" height="100" viewBox="0 0 50 100"><path d="M25,0 Q20,29.09 25,58.19 Q30,29.09 25,0 Z" fill="#EA580C"/></svg>',
        ),
      ),
    ),
    Positioned(
      top: height * 0.01,
      left: width * 0.56,
      child: Opacity(
        opacity: 0.32,
        child: SvgPicture.string(
          '<svg width="50" height="100" viewBox="0 0 50 100"><path d="M25,0 Q20,18.40 25,36.81 Q30,18.40 25,0 Z" fill="#4A1D96"/></svg>',
        ),
      ),
    ),
    // Círculo exemplo
    Positioned(
      top: height * 0.31,
      left: width * 0.08,
      child: Opacity(
        opacity: 0.68,
        child: SvgPicture.string(
          '<svg width="10" height="10" viewBox="0 0 10 10"><circle cx="5" cy="5" r="2.6" fill="#4ade80"/></svg>',
        ),
      ),
    ),
    // Adicione mais SVGs conforme o HTML para enriquecer o visual
  ];
} 