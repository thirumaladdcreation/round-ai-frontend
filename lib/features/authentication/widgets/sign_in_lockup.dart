import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/constants/app_assets.dart';

/// Original RoundsAI mark and wordmark, kept at their source proportions.
class SignInLockup extends StatelessWidget {
  const SignInLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color line = dark ? RoundsBrand.white : RoundsBrand.charcoal;
    return Column(
      children: <Widget>[
        const SignInLogoMark(),
        const SizedBox(height: 10),
        const SignInWordmark(),
        const SizedBox(height: 14),
        Text(
          'Smarter Rounds.',
          style: AppTypography.inter(
            AppTypography.medium(fontSize: 16, color: line, height: 1.3),
          ),
        ),
        Text(
          'Better Care.',
          style: AppTypography.inter(
            AppTypography.semiBold(
              fontSize: 16,
              color: RoundsBrand.aqua,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class SignInLogoMark extends StatelessWidget {
  const SignInLogoMark({super.key});

  static const double _canvasWidth = 1536;
  static const double _canvasHeight = 1024;
  static const double _contentLeft = 492;
  static const double _contentTop = 252;
  static const double _contentWidth = 522;
  static const double _contentHeight = 584;
  static const double _visibleWidth = 62;

  @override
  Widget build(BuildContext context) {
    final double scale = _visibleWidth / _contentWidth;
    final double canvasWidth = _canvasWidth * scale;
    final double canvasHeight = _canvasHeight * scale;
    return Semantics(
      label: 'RoundsAI',
      image: true,
      child: SizedBox(
        width: _visibleWidth,
        height: _contentHeight * scale,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: canvasWidth,
            maxWidth: canvasWidth,
            minHeight: canvasHeight,
            maxHeight: canvasHeight,
            child: Transform.translate(
              offset: Offset(-_contentLeft * scale, -_contentTop * scale),
              child: Image.asset(
                AppAssets.logoMark,
                width: canvasWidth,
                height: canvasHeight,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignInWordmark extends StatelessWidget {
  const SignInWordmark({this.width = 228, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double height = width * (724 / 2172);
    final Widget image = Image.asset(
      AppAssets.logoWordmark,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    return Semantics(
      label: 'rounds AI',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: dark
            ? image
            : Stack(
                children: <Widget>[
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      RoundsBrand.charcoal,
                      BlendMode.srcIn,
                    ),
                    child: image,
                  ),
                  ClipRect(
                    clipper: const SignInBadgeClipper(),
                    child: Image(
                      image: const AssetImage(AppAssets.logoWordmark),
                      width: width,
                      height: height,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Keeps the aqua AI badge from the original wordmark on light backgrounds.
class SignInBadgeClipper extends CustomClipper<Rect> {
  const SignInBadgeClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(size.width * 0.74, 0, size.width * 0.26, size.height);
  }

  @override
  bool shouldReclip(covariant SignInBadgeClipper oldClipper) => false;
}
