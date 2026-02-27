import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/config/app_colors.dart';

class AppLogo extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? textColor;
  final FontWeight? fontWeight;
  final bool showShadow;
  final List<Shadow>? shadows;
  final TextAlign? textAlign;
  final EdgeInsets? padding;
  final TextStyle? textStyle;

  const AppLogo({
    Key? key,
    this.text = 'NOFLX UNB',
    this.fontSize = 36,
    this.textColor = AppColors.white,
    this.fontWeight = FontWeight.normal,
    this.showShadow = true,
    this.shadows,
    this.textAlign = TextAlign.center,
    this.padding = const EdgeInsets.only(left: 50.0),
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultShadows = showShadow
        ? [
            const Shadow(
              color: Color.fromARGB(77, 0, 0, 0),
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ]
        : <Shadow>[];

    return Padding(
      padding: padding!,
      child: Text(
        text,
        textAlign: textAlign,
        style: textStyle ??
            GoogleFonts.permanentMarker(
              fontSize: fontSize,
              color: textColor,
              fontWeight: fontWeight,
              shadows: shadows ?? defaultShadows,
            ),
      ),
    );
  }
}
