import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';

/// Text where `[... not entered]` parts are highlighted, so missing chart
/// information cannot be read as if it were written.
class PlaceholderText extends StatelessWidget {
  const PlaceholderText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in notEnteredPlaceholder.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(
            color: colors.warning,
            fontWeight: FontWeight.w600,
            backgroundColor: colors.warningSoft,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
