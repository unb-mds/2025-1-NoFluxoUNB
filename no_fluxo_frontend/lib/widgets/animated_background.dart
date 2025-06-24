import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Fundo escuro
          Container(color: Colors.black),
          // Círculos coloridos borrados animados
          const _AnimatedSmoke(
            size: 300,
            color: Color(0xFF6B19C9),
            topPercent: 0.10,
            leftPercent: 0.05,
            durationSeconds: 18,
          ),
          const _AnimatedSmoke(
            size: 400,
            color: Color(0xFFE63783),
            topPercent: 0.60,
            leftPercent: 0.70,
            durationSeconds: 22,
          ),
          const _AnimatedSmoke(
            size: 350,
            color: Color(0xFFF0C419),
            topPercent: 0.30,
            leftPercent: 0.60,
            durationSeconds: 20,
          ),
          const _AnimatedSmoke(
            size: 250,
            color: Color(0xFF6B19C9),
            topPercent: 0.70,
            leftPercent: 0.20,
            durationSeconds: 19,
          ),
          const _AnimatedSmoke(
            size: 200,
            color: Color(0xFFE63783),
            topPercent: 0.15,
            leftPercent: 0.80,
            durationSeconds: 17,
          ),
          const _AnimatedSmoke(
            size: 262,
            color: Color(0xFFF0C419),
            topPercent: 0.51,
            leftPercent: 0.76,
            durationSeconds: 21,
          ),
          const _AnimatedSmoke(
            size: 445,
            color: Color(0xFFF0C419),
            topPercent: 0.76,
            leftPercent: 0.43,
            durationSeconds: 25,
          ),
          const _AnimatedSmoke(
            size: 443,
            color: Color(0xFFE63783),
            topPercent: 0.18,
            leftPercent: 0.58,
            durationSeconds: 23,
          ),
          const _AnimatedSmoke(
            size: 288,
            color: Color(0xFFE63783),
            topPercent: 0.24,
            leftPercent: 0.94,
            durationSeconds: 16,
          ),
          const _AnimatedSmoke(
            size: 439,
            color: Color(0xFFF0C419),
            topPercent: 0.19,
            leftPercent: 0.40,
            durationSeconds: 24,
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
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.durationSeconds),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -0.03, end: 0.03).animate(
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
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: height * (widget.topPercent + _animation.value),
          left: width * (widget.leftPercent + _animation.value),
          child: Opacity(
            opacity: 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.55),
                    blurRadius: widget.size * 1.6,
                    spreadRadius: widget.size * 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
