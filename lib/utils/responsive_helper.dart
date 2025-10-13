import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
      MediaQuery.of(context).size.width >= 650;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isMediumMobile(BuildContext context) =>
      MediaQuery.of(context).size.width >= 360 && 
      MediaQuery.of(context).size.width < 480;

  static bool isLargeMobile(BuildContext context) =>
      MediaQuery.of(context).size.width >= 480 && 
      MediaQuery.of(context).size.width < 650;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseSize * 0.75; // Very small screens
    } else if (screenWidth < 480) {
      return baseSize * 0.85; // Small mobile
    } else if (screenWidth < 600) {
      return baseSize * 0.9; // Medium mobile
    } else if (screenWidth < 900) {
      return baseSize; // Large mobile/tablet
    } else {
      return baseSize * 1.1; // Desktop
    }
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return const EdgeInsets.all(8); // Very small screens
    } else if (screenWidth < 480) {
      return const EdgeInsets.all(12); // Small mobile
    } else if (screenWidth < 600) {
      return const EdgeInsets.all(16); // Medium mobile
    } else if (screenWidth < 900) {
      return const EdgeInsets.all(20); // Large mobile/tablet
    } else {
      return const EdgeInsets.all(24); // Desktop
    }
  }

  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseSpacing * 0.6; // Very small screens
    } else if (screenWidth < 480) {
      return baseSpacing * 0.75; // Small mobile
    } else if (screenWidth < 600) {
      return baseSpacing * 0.85; // Medium mobile
    } else if (screenWidth < 900) {
      return baseSpacing; // Large mobile/tablet
    } else {
      return baseSpacing * 1.2; // Desktop
    }
  }

  static int getResponsiveGridCrossAxisCount(BuildContext context) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return 1; // Very small screens
    } else if (screenWidth < 480) {
      return 1; // Small mobile
    } else if (screenWidth < 600) {
      return 2; // Medium mobile
    } else if (screenWidth < 900) {
      return 3; // Large mobile/tablet
    } else {
      return 4; // Desktop
    }
  }

  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseSize * 0.7; // Very small screens
    } else if (screenWidth < 480) {
      return baseSize * 0.8; // Small mobile
    } else if (screenWidth < 600) {
      return baseSize * 0.9; // Medium mobile
    } else if (screenWidth < 900) {
      return baseSize; // Large mobile/tablet
    } else {
      return baseSize * 1.1; // Desktop
    }
  }

  static double getResponsiveButtonHeight(BuildContext context) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return 40; // Very small screens
    } else if (screenWidth < 480) {
      return 44; // Small mobile
    } else if (screenWidth < 600) {
      return 48; // Medium mobile
    } else {
      return 52; // Large screens
    }
  }

  static double getResponsiveButtonWidth(BuildContext context, double baseWidth) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseWidth * 0.8; // Very small screens
    } else if (screenWidth < 480) {
      return baseWidth * 0.9; // Small mobile
    } else if (screenWidth < 600) {
      return baseWidth; // Medium mobile
    } else {
      return baseWidth * 1.1; // Large screens
    }
  }

  static Widget responsiveBuilder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }

  static Widget responsiveTextBuilder({
    required BuildContext context,
    required String text,
    required TextStyle style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: style.copyWith(
        fontSize: getResponsiveFontSize(context, style.fontSize ?? 14),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    double screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    } else if (screenWidth < 480) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    } else if (screenWidth < 600) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    } else if (screenWidth < 900) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    }
  }
}
