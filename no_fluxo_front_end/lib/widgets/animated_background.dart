import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withOpacity(0.8),
            AppColors.pink.withOpacity(0.8),
            AppColors.yellow.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: SmokeEffect(
              size: 300,
              color: AppColors.purple.withOpacity(0.3),
            ),
          ),
          Positioned(
            top: 200,
            right: -100,
            child: SmokeEffect(
              size: 250,
              color: AppColors.pink.withOpacity(0.3),
            ),
          ),
          Positioned(
            bottom: -100,
            left: 100,
            child: SmokeEffect(
              size: 280,
              color: AppColors.yellow.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class SmokeEffect extends StatefulWidget {
  final double size;
  final Color color;

  const SmokeEffect({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  State<SmokeEffect> createState() => _SmokeEffectState();
}

class _SmokeEffectState extends State<SmokeEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            widget.size * 0.2 * _animation.value,
            widget.size * 0.1 * _animation.value,
          ),
          child: Opacity(
            opacity: 0.5 + 0.5 * _animation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.1),
                    blurRadius: widget.size * 0.3,
                    spreadRadius: widget.size * 0.1,
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