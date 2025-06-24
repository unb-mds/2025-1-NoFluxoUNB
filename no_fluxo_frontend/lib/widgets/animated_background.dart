import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Fundo preto puro
          Container(color: Colors.black),
          // Fumaças redondas, muito borradas, tamanho moderado
          const _AnimatedSmoke(
            size: 180,
            color: Color(0xFF6B19C9),
            topPercent: 0.10,
            leftPercent: 0.05,
            durationSeconds: 40,
          ),
          const _AnimatedSmoke(
            size: 220,
            color: Color(0xFFE63783),
            topPercent: 0.60,
            leftPercent: 0.70,
            durationSeconds: 50,
          ),
          const _AnimatedSmoke(
            size: 200,
            color: Color(0xFFF0C419),
            topPercent: 0.30,
            leftPercent: 0.60,
            durationSeconds: 45,
          ),
          const _AnimatedSmoke(
            size: 140,
            color: Color(0xFF6B19C9),
            topPercent: 0.70,
            leftPercent: 0.20,
            durationSeconds: 38,
          ),
          const _AnimatedSmoke(
            size: 210,
            color: Color(0xFFF0C419),
            topPercent: 0.76,
            leftPercent: 0.43,
            durationSeconds: 55,
          ),
        ],
      ),
    );
  }
}

class _AnimatedSmoke extends StatefulWidget {
  final double size;
  final Color color;
  final double topPercent;
  final double leftPercent;
  final int durationSeconds;

  const _AnimatedSmoke({
    super.key,
    required this.size,
    required this.color,
    required this.topPercent,
    required this.leftPercent,
    required this.durationSeconds,
  });

  @override
  State<_AnimatedSmoke> createState() => _AnimatedSmokeState();
}

class _AnimatedSmokeState extends State<_AnimatedSmoke>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _moveAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.durationSeconds),
      vsync: this,
    )..repeat(reverse: true);
    // Movimento levemente diagonal e orgânico
    _moveAnim = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    // Escala para efeito de "respiração"
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    // Opacidade "respirando"
    _opacityAnim = Tween<double>(begin: 0.45, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: height * (widget.topPercent + _moveAnim.value),
          left: width * (widget.leftPercent + _moveAnim.value),
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.65),
                      blurRadius: widget.size * 1.5, // ainda muito borrado
                      spreadRadius: widget.size * 0.7, // ainda muito borrado
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
