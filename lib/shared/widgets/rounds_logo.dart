import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

class RoundsLogo extends StatelessWidget {
  const RoundsLogo({this.size = 96, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: CustomPaint(painter: _RoundsMarkPainter()),
    );
  }
}

class RoundsWordmark extends StatelessWidget {
  const RoundsWordmark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RoundsLogo(size: compact ? 28 : 36),
        const SizedBox(width: 8),
        Text(
          'RoundsAI',
          style: AppTypography.bold(
            fontSize: compact ? 18 : 22,
            color: AppColors.of(context).navy,
          ),
        ),
      ],
    );
  }
}

class _RoundsMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint fill = Paint()
      ..shader = AppColors.logoGradient.createShader(bounds);

    final double w = size.width;
    final double h = size.height;
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.02, w * 0.84, h * 0.96),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(body, fill);

    final Paint cut = Paint()..color = const Color(0xFFF7FBFF);
    final Path letter = Path()
      ..moveTo(w * 0.28, h * 0.18)
      ..lineTo(w * 0.28, h * 0.82)
      ..lineTo(w * 0.40, h * 0.82)
      ..lineTo(w * 0.40, h * 0.56)
      ..lineTo(w * 0.58, h * 0.82)
      ..lineTo(w * 0.74, h * 0.82)
      ..lineTo(w * 0.52, h * 0.52)
      ..lineTo(w * 0.66, h * 0.52)
      ..quadraticBezierTo(w * 0.78, h * 0.52, w * 0.78, h * 0.36)
      ..quadraticBezierTo(w * 0.78, h * 0.18, w * 0.62, h * 0.18)
      ..close();
    canvas.drawPath(letter, cut);

    final Paint pulse = Paint()
      ..color = const Color(0xFFBFDBFE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path beat = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..lineTo(w * 0.38, h * 0.50)
      ..lineTo(w * 0.44, h * 0.34)
      ..lineTo(w * 0.52, h * 0.66)
      ..lineTo(w * 0.58, h * 0.50)
      ..lineTo(w * 0.82, h * 0.50);
    canvas.drawPath(beat, pulse);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
