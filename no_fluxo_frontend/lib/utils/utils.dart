import 'package:flutter/material.dart';
import 'package:mobile_app/config/size_config.dart';
import 'package:mobile_app/config/app_colors.dart';

class Utils {
  static Future<void> showCustomizedDialog(
      {required BuildContext context,
      required Widget child,
      bool barrierDismissible = true}) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return Dialog(
          elevation: 5,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.dialogBackground,
              border:
                  Border.all(color: AppColors.white.withOpacity(0.1), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: BoxConstraints(
              maxWidth: getProportionateScreenWidth(500),
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              minHeight: getProportionateScreenHeight(300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
