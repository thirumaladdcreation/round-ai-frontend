import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Responsive sizing. Phone designs are based on a 390 × 844 frame.
class ScreenUtils {
  ScreenUtils._();

  static const double designWidth = 390;
  static const double designHeight = 844;

  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double _scaleWidth;
  static late double _scaleHeight;
  static late double _scaleText;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;
  static bool get isTablet => shortSide >= 600;
  static double get shortSide => math.min(screenWidth, screenHeight);
  static double get longSide => math.max(screenWidth, screenHeight);

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    _scaleWidth = screenWidth / designWidth;
    _scaleHeight = screenHeight / designHeight;
    _scaleText = math.min(_scaleWidth, _scaleHeight);
    _initialized = true;
  }

  static double w(double width) {
    assert(_initialized, 'Call ScreenUtils.init(context) before using sizes.');
    return width * _scaleWidth;
  }

  static double h(double height) {
    assert(_initialized, 'Call ScreenUtils.init(context) before using sizes.');
    return height * _scaleHeight;
  }

  static double sp(double fontSize) {
    assert(_initialized, 'Call ScreenUtils.init(context) before using sizes.');
    return fontSize * _scaleText;
  }

  static double r(double radius) {
    assert(_initialized, 'Call ScreenUtils.init(context) before using sizes.');
    return radius * _scaleText;
  }

  static EdgeInsets get padding => _mediaQueryData.padding;
  static double get topSafe => _mediaQueryData.padding.top;
  static double get bottomSafe => _mediaQueryData.padding.bottom;
}
