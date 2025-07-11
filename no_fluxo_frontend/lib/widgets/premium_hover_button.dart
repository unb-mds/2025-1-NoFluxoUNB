import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumHoverButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final List<Color> colors;

  const PremiumHoverButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  State<PremiumHoverButton> createState() => _PremiumHoverButtonState();
}

class _PremiumHoverButtonState extends State<PremiumHoverButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<Offset> _shadowAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.35,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));

    _shadowAnimation = Tween<Offset>(
      begin: const Offset(0, 2),
      end: const Offset(0, 8),
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    if (!widget.isActive && !_isHovered) {
      setState(() {
        _isHovered = true;
      });
      _hoverController.forward();
      _shimmerController.repeat();
    }
  }

  void _onHoverExit() {
    if (_isHovered) {
      setState(() {
        _isHovered = false;
      });
      _hoverController.reverse();
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _hoverController,
            _scaleController,
            _shimmerController,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 48,
                ),
                decoration: BoxDecoration(
                  gradient: widget.isActive
                      ? LinearGradient(colors: widget.colors)
                      : null,
                  color:
                      widget.isActive ? null : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: widget.isActive
                        ? Colors.transparent
                        : _isHovered
                            ? widget.colors[0].withOpacity(0.5)
                            : Colors.white.withOpacity(0.18),
                    width: 2,
                  ),
                  boxShadow: [
                    if (widget.isActive)
                      BoxShadow(
                        color: widget.colors[0].withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    if (_isHovered && !widget.isActive)
                      BoxShadow(
                        color: widget.colors[0].withOpacity(0.45),
                        blurRadius: _elevationAnimation.value + 4,
                        offset: _shadowAnimation.value,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Overlay de hover
                      if (_isHovered && !widget.isActive)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                colors: widget
                                    .colors, // Use as mesmas cores do estado ativo
                              ),
                            ),
                          ),
                        ),

                      // Conteúdo principal
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 18),
                        child: Text(
                          widget.label,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
