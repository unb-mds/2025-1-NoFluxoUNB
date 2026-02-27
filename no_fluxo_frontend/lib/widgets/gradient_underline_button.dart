import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/config/app_colors.dart';

class GradientUnderlineButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final double? fontSize;
  final Color? textColor;
  final FontWeight? fontWeight;
  final List<Color>? gradientColors;
  final Duration? animationDuration;
  final Curve? animationCurve;
  final double? underlineHeight;
  final EdgeInsets? padding;
  final TextStyle? textStyle;

  const GradientUnderlineButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.fontSize = 19,
    this.textColor = AppColors.white,
    this.fontWeight = FontWeight.bold,
    this.gradientColors = const [AppColors.purple, AppColors.pink],
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
    this.underlineHeight = 2,
    this.padding,
    this.textStyle,
  }) : super(key: key);

  @override
  State<GradientUnderlineButton> createState() =>
      _GradientUnderlineButtonState();
}

class _GradientUnderlineButtonState extends State<GradientUnderlineButton> {
  final GlobalKey _textKey = GlobalKey();
  double _textWidth = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTextWidth();
    });
  }

  void _updateTextWidth() {
    final RenderBox? renderBox =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _textWidth = renderBox.size.width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          TextButton(
            key: _textKey,
            onPressed: widget.onPressed,
            style: TextButton.styleFrom(
              padding: widget.padding,
            ),
            child: Text(
              widget.text,
              style: widget.textStyle ??
                  GoogleFonts.permanentMarker(
                    fontSize: widget.fontSize,
                    color: widget.textColor,
                    fontWeight: widget.fontWeight,
                  ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: AnimatedContainer(
              duration: widget.animationDuration!,
              curve: widget.animationCurve!,
              height: widget.underlineHeight,
              width: _isHovered ? _textWidth : 0.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors!,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
