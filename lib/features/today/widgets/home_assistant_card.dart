import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/router/app_routes.dart';

/// Single primary home action — start a round from the patient list.
///
/// Layout matches mockup: [image] then Column(title, subtitle, button).
class HomeAssistantCard extends StatelessWidget {
  const HomeAssistantCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF0B2C5C),
            Color(0xFF0A6E8A),
            Color(0xFF0AABB8),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0B2C5C).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
          // Row: 1st = image, 2nd = Column(title, subtitle, button)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const _BrainImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'RoundsAI Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bold(
                          fontSize: 16,
                          height: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get patient summary, plans and insights instantly.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.regular(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: const Color(0xFFB8E8F5),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () => context.go(AppRoutes.census),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Color(0xFF0B2C5C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Start New Round',
                                    style: AppTypography.semiBold(
                                      fontSize: 13,
                                      color: const Color(0xFF0B2C5C),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '›',
                                    style: AppTypography.semiBold(
                                      fontSize: 15,
                                      height: 1,
                                      color: const Color(0xFF0B2C5C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing circular brain mark — left child of the assistant card Row.
class _BrainImage extends StatelessWidget {
  const _BrainImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  const Color(0xFF7DE8FF).withValues(alpha: 0.55),
                  const Color(0xFF0AABB8).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF062A4A).withValues(alpha: 0.55),
              border: Border.all(
                color: const Color(0xFF7DE8FF).withValues(alpha: 0.85),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF7DE8FF).withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Color(0xFFB8F0FF),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft dotted accents in card corners (mockup detail).
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    void drawCluster(Offset origin, int cols, int rows) {
      const double step = 7;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final double dx = origin.dx + c * step;
          final double dy = origin.dy + r * step;
          if (dx < 0 || dy < 0 || dx > size.width || dy > size.height) {
            continue;
          }
          // Fade toward outer edge.
          final double t = 1 - (r + c) / (rows + cols);
          paint.color = Colors.white.withValues(alpha: 0.06 + 0.1 * t);
          canvas.drawCircle(Offset(dx, dy), 1.1, paint);
        }
      }
    }

    drawCluster(Offset(size.width - 56, 10), 7, 5);
    drawCluster(const Offset(10, 0), 5, 4);
    // Bottom-left cluster, flipped vertically.
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 6; c++) {
        final double dx = 12.0 + c * 7;
        final double dy = size.height - 14 - r * 7;
        final double t = 1 - (r + c) / 11;
        paint.color = Colors.white.withValues(alpha: 0.05 + 0.09 * t);
        canvas.drawCircle(Offset(dx, dy), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
