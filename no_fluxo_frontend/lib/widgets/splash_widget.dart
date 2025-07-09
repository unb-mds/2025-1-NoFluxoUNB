import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget>
    with TickerProviderStateMixin {
  late AnimationController _barController;
  late AnimationController _particle1Controller;
  late AnimationController _particle2Controller;
  late AnimationController _particle3Controller;
  late AnimationController _particle4Controller;
  late AnimationController _particle5Controller;
  late AnimationController _textController;

  late Animation<double> _barAnimation;
  late Animation<double> _particle1Animation;
  late Animation<double> _particle2Animation;
  late Animation<double> _particle3Animation;
  late Animation<double> _particle4Animation;
  late Animation<double> _particle5Animation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _textSpacingAnimation;

  @override
  void initState() {
    super.initState();

    // Bar animation controller (2.5s linear infinite)
    _barController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Start bar animation after a short delay to ensure widget is mounted
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _barController.repeat();
      }
    });

    _barAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _barController, curve: Curves.linear),
    );

    // Particle controllers with different durations and delays
    _particle1Controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _particle2Controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    _particle3Controller = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _particle4Controller = AnimationController(
      duration: const Duration(milliseconds: 1150),
      vsync: this,
    );

    _particle5Controller = AnimationController(
      duration: const Duration(milliseconds: 1250),
      vsync: this,
    );

    // Text animation controller (1.2s ease-in-out infinite alternate)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start text animation after a short delay to ensure widget is mounted
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _textController.repeat(reverse: true);
      }
    });

    // Particle animations
    _particle1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particle1Controller, curve: Curves.easeInOut),
    );

    _particle2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particle2Controller, curve: Curves.easeInOut),
    );

    _particle3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particle3Controller, curve: Curves.easeInOut),
    );

    _particle4Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particle4Controller, curve: Curves.easeInOut),
    );

    _particle5Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particle5Controller, curve: Curves.easeInOut),
    );

    // Text animations
    _textOpacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _textSpacingAnimation = Tween<double>(begin: 2.0, end: 4.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Start particle animations with delays
    _startParticleAnimations();
  }

  void _startParticleAnimations() {
    if (!mounted) return;

    _particle1Controller.repeat();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _particle2Controller.repeat();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _particle3Controller.repeat();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _particle4Controller.repeat();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _particle5Controller.repeat();
    });
  }

  @override
  void dispose() {
    // Stop all animations before disposing
    _barController.stop();
    _particle1Controller.stop();
    _particle2Controller.stop();
    _particle3Controller.stop();
    _particle4Controller.stop();
    _particle5Controller.stop();
    _textController.stop();

    // Dispose all controllers
    _barController.dispose();
    _particle1Controller.dispose();
    _particle2Controller.dispose();
    _particle3Controller.dispose();
    _particle4Controller.dispose();
    _particle5Controller.dispose();
    _textController.dispose();

    super.dispose();
  }

  double _getParticleY(double animationValue) {
    // Replicating the CSS keyframes jump animation
    if (animationValue <= 0.3) {
      // 0% to 30%: translateY(0) to translateY(-32px) scale(1) to scale(1.15)
      return -32 * (animationValue / 0.3);
    } else if (animationValue <= 0.5) {
      // 30% to 50%: translateY(-32px) to translateY(-18px) scale(1.15) to scale(1.1)
      double progress = (animationValue - 0.3) / 0.2;
      return -32 + (14 * progress); // -32 to -18
    } else if (animationValue <= 0.7) {
      // 50% to 70%: translateY(-18px) to translateY(-32px) scale(1.1) to scale(1.15)
      double progress = (animationValue - 0.5) / 0.2;
      return -18 - (14 * progress); // -18 to -32
    } else {
      // 70% to 100%: translateY(-32px) to translateY(0) scale(1.15) to scale(1)
      double progress = (animationValue - 0.7) / 0.3;
      return -32 + (32 * progress); // -32 to 0
    }
  }

  double _getParticleScale(double animationValue) {
    if (animationValue <= 0.3) {
      return 1.0 + (0.15 * (animationValue / 0.3)); // 1.0 to 1.15
    } else if (animationValue <= 0.5) {
      double progress = (animationValue - 0.3) / 0.2;
      return 1.15 - (0.05 * progress); // 1.15 to 1.1
    } else if (animationValue <= 0.7) {
      double progress = (animationValue - 0.5) / 0.2;
      return 1.1 + (0.05 * progress); // 1.1 to 1.15
    } else {
      double progress = (animationValue - 0.7) / 0.3;
      return 1.15 - (0.15 * progress); // 1.15 to 1.0
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.0, -1.0), // 135deg
            end: Alignment(1.0, 1.0),
            colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
          ),
        ),
        child: Stack(
          children: [
            // Gradiente de fundo (mesmo da home)
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

            // Brick wall overlay (mesmo da home)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _BrickWallPainter(),
            ),

            // SVGs coloridos (mesmo da home)
            ..._graffitiSVGs(context),

            // Loader Container
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress Bar
                  Container(
                    width: 320,
                    height: 32,
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3498DB).withOpacity(0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Animated Bar
                          AnimatedBuilder(
                            animation: _barAnimation,
                            builder: (context, child) {
                              return Container(
                                width: double.infinity,
                                height: double.infinity,
                                child: CustomPaint(
                                  painter: AnimatedGradientPainter(
                                      _barAnimation.value),
                                ),
                              );
                            },
                          ),

                          // Particles
                          ...List.generate(5, (index) {
                            final controllers = [
                              _particle1Controller,
                              _particle2Controller,
                              _particle3Controller,
                              _particle4Controller,
                              _particle5Controller,
                            ];

                            final animations = [
                              _particle1Animation,
                              _particle2Animation,
                              _particle3Animation,
                              _particle4Animation,
                              _particle5Animation,
                            ];

                            final colors = [
                              const Color(0xFF43CEA2),
                              const Color(0xFFFF5E62),
                              const Color(0xFFF9D423),
                              const Color(0xFF8E44AD),
                              const Color(0xFF36D1C4),
                            ];

                            final positions = [0.1, 0.3, 0.5, 0.7, 0.85];

                            return AnimatedBuilder(
                              animation: animations[index],
                              builder: (context, child) {
                                double y =
                                    _getParticleY(animations[index].value);
                                double scale =
                                    _getParticleScale(animations[index].value);

                                return Positioned(
                                  left: 320 * positions[index] -
                                      9, // Center the 18px particle
                                  bottom: 8 + y,
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: colors[index],
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.10),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Loading Text
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_textOpacityAnimation, _textSpacingAnimation]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Text(
                          'Carregando...',
                          style: TextStyle(
                            fontSize: 20.8, // 1.3rem ≈ 20.8px
                            color: Colors.black,
                            letterSpacing: _textSpacingAnimation.value,
                            fontFamily: 'Segoe UI',
                            fontWeight: FontWeight.normal,
                            shadows: [
                              Shadow(
                                color:
                                    const Color(0xFF3498DB).withOpacity(0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for animated gradient bar
class AnimatedGradientPainter extends CustomPainter {
  final double animationValue;

  AnimatedGradientPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Create gradient that moves horizontally like CSS background-position
    const colors = [
      Color(0xFF43CEA2),
      Color(0xFF185A9D),
      Color(0xFFFF5E62),
      Color(0xFFF9D423),
      Color(0xFF8E44AD),
    ];

    // CSS: background-size: 300% 100% with background-position moving from 0% to 100%
    final gradientWidth = size.width * 3; // 300% of container width
    final startX = -gradientWidth * animationValue;
    final endX = startX + gradientWidth;

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
    );

    final shader = gradient.createShader(
      Rect.fromLTWH(startX, 0, gradientWidth, size.height),
    );

    paint.shader = shader;
    paint.color = paint.color.withOpacity(0.7); // CSS opacity: 0.7

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant AnimatedGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Brick wall painter (mesmo da home)
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

// SVGs coloridos (mesmo da home)
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
