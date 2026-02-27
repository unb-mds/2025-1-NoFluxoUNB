import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/config/app_colors.dart';

class GradientCTAButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final double? fontSize;
  final Color? textColor;
  final FontWeight? fontWeight;
  final List<Color>? gradientColors;
  final Duration? animationDuration;
  final Curve? animationCurve;
  final double? scaleOnHover;
  final double? borderRadius;
  final EdgeInsets? padding;
  final BoxConstraints? constraints;
  final TextStyle? textStyle;
  final bool enableScaleAnimation;

  const GradientCTAButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.fontSize = 19,
    this.textColor = AppColors.white,
    this.fontWeight = FontWeight.bold,
    this.gradientColors = const [AppColors.purple, AppColors.pink],
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
    this.scaleOnHover = 1.05,
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
    this.constraints = const BoxConstraints(minWidth: 260.0, minHeight: 40.0),
    this.textStyle,
    this.enableScaleAnimation = true,
  }) : super(key: key);

  @override
  State<GradientCTAButton> createState() => _GradientCTAButtonState();
}

class _GradientCTAButtonState extends State<GradientCTAButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: widget.enableScaleAnimation && _isHovered
            ? widget.scaleOnHover!
            : 1.0,
        duration: widget.animationDuration!,
        curve: widget.animationCurve!,
        child: TextButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: widget.padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius!),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors!,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius!),
            ),
            constraints: widget.constraints,
            alignment: Alignment.center,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: widget.textStyle ??
                  GoogleFonts.permanentMarker(
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    color: widget.textColor,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
