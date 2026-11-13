import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

final RegExp chatMentionPattern = RegExp(r'@([A-Za-z][A-Za-z0-9._-]{1,40})');

/// Builds rich text that highlights `@Mentions` without logging content.
InlineSpan buildMentionSpans(
  String text, {
  required AppColors colors,
  TextStyle? base,
}) {
  final TextStyle style =
      base ??
      AppTypography.regular(fontSize: 15, color: colors.textPrimary);
  if (text.isEmpty) return TextSpan(text: text, style: style);

  final List<InlineSpan> spans = <InlineSpan>[];
  int start = 0;
  for (final RegExpMatch match in chatMentionPattern.allMatches(text)) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start), style: style));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  return TextSpan(children: spans, style: style);
}

/// Active `@query` just before the cursor, if any.
({int start, String query})? mentionQueryAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final String before = text.substring(0, cursor);
  final int at = before.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0) {
    final String prev = before[at - 1];
    if (RegExp(r'[A-Za-z0-9_]').hasMatch(prev)) return null;
  }
  final String token = before.substring(at + 1);
  if (token.contains(RegExp(r'\s'))) return null;
  return (start: at, query: token);
}
