import 'package:flutter/material.dart';

/// Breakpoints for phone / tablet / desktop layouts.
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1000;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => widthOf(context) < mobile;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) => widthOf(context) >= tablet;
}
