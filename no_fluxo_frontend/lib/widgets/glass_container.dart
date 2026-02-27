import 'package:flutter/material.dart';
import 'dart:ui';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final AlignmentGeometry? alignment;

  const GlassContainer({
    Key? key,
    required this.child,
    this.sigmaX = 4.0,
    this.sigmaY = 4.0,
    this.backgroundColor = const Color.fromRGBO(0, 0, 0, 0.3),
    this.borderRadius = 0.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.border,
    this.boxShadow,
    this.gradient,
    this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      constraints: constraints,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigmaX,
            sigmaY: sigmaY,
          ),
          child: Container(
            padding: padding,
            alignment: alignment,
            decoration: BoxDecoration(
              color: gradient == null ? backgroundColor : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border,
              boxShadow: boxShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
} 