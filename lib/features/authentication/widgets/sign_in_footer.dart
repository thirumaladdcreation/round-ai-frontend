import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

class SignInFooter extends StatelessWidget {
  const SignInFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color text = dark
        ? RoundsBrand.pale.withValues(alpha: 0.82)
        : RoundsBrand.charcoal.withValues(alpha: 0.78);
    return Column(
      children: <Widget>[
        const SignInPulse(),
        const SizedBox(height: 8),
        Text(
          'Secure access for healthcare professionals',
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            AppTypography.regular(color: text, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class SignInPulse extends StatelessWidget {
  const SignInPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(72, 16),
      painter: SignInPulsePainter(color: RoundsBrand.aqua),
    );
  }
}

class SignInPulsePainter extends CustomPainter {
  const SignInPulsePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.28, size.height * 0.55)
      ..lineTo(size.width * 0.36, size.height * 0.12)
      ..lineTo(size.width * 0.46, size.height * 0.92)
      ..lineTo(size.width * 0.56, size.height * 0.38)
      ..lineTo(size.width * 0.64, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.55);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant SignInPulsePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
