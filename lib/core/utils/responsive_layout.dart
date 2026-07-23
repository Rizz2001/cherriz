import 'package:flutter/material.dart';

/// Breakpoint Constants for Cherriz ERP
class ResponsiveBreakpoints {
  static const double mobile = 650.0;
  static const double desktop = 1100.0;
}

/// Extension on BuildContext for quick responsive checks and screen sizing
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobile;
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.mobile &&
      screenWidth < ResponsiveBreakpoints.desktop;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.desktop;

  /// Helper to return values based on screen size
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}

/// ResponsiveBuilder Widget
/// Chooses layout depending on screen width constraints.
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) => context.isMobile;
  static bool isTablet(BuildContext context) => context.isTablet;
  static bool isDesktop(BuildContext context) => context.isDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
          return desktop;
        }
        if (constraints.maxWidth >= ResponsiveBreakpoints.mobile) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
