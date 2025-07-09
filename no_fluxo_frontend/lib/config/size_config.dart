import 'package:flutter/material.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static double? defaultSize;
  static Orientation? orientation;
  static late double normalSpacing;
  static late double largeSpacing;
  static late double figmaScreenWidth;
  static late double figmaScreenHeight;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
    normalSpacing = getProportionateScreenHeight(10);
    largeSpacing = getProportionateScreenHeight(20);
    if (isDesktop()) {
      figmaScreenHeight = 1025.0;
      figmaScreenWidth = 1440.0;
    }
    if (isTable()) {
      figmaScreenHeight = 1024;
      figmaScreenWidth = 768;
    } else {
      figmaScreenWidth = 393.0;
      figmaScreenHeight = 852.0;
    }
  }
}

bool isDesktop() {
  return SizeConfig.screenWidth >= 1025 ||
      SizeConfig.screenWidth / SizeConfig.screenHeight >= 1;
}

bool isTable() {
  return SizeConfig.screenWidth >= 768 ||
      SizeConfig.screenWidth / SizeConfig.screenHeight >= 1;
}

double getWidthToHeightRatio() {
  return SizeConfig.screenWidth / SizeConfig.screenHeight;
}

// Get the proportionate height as per screen size
double getProportionateScreenHeight(double inputHeight) {
  double screenHeight = SizeConfig.screenHeight;
  // 812 is the layout height that designer use
  if (isDesktop()) {
    return (inputHeight / 1025.0) * screenHeight;
  }
  return (inputHeight / 812.0) * screenHeight;
}

// Get the proportionate height as per screen size
double getProportionateScreenWidth(double inputWidth) {
  double screenWidth = SizeConfig.screenWidth;
  // 375 is the layout width that designer use
  if (isDesktop()) {
    return (inputWidth / 1440.0) * screenWidth;
  }
  return (inputWidth / 375.0) * screenWidth;
}

double getProportionateFontSize(double figmaFontSize) {
  return (figmaFontSize / SizeConfig.figmaScreenHeight) *
      SizeConfig.screenHeight;
}
