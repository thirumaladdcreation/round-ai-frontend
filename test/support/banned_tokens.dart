import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wire / dump tokens that must never appear as visible clinician UI text.
final RegExp bannedClinicalUiToken = RegExp(
  r'clinician_|fact_id|snake_case|\bdelta\b|\bdirection\b|\bnull\b|\bundefined\b|'
  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|'
  r'\{[^}]{0,40}\}|\[object Object\]',
  caseSensitive: false,
);

bool textLooksBanned(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return false;
  // Allow the humanized clinician_plan copy.
  if (t.contains("Today's Assessment and Plan not entered") ||
      t.contains("Today's plan not entered")) {
    return false;
  }
  if (t.contains('clinician_plan') || t.contains('clinician_')) return true;
  if (bannedClinicalUiToken.hasMatch(t)) return true;
  return false;
}

/// Fails the test if any visible [Text]/[EditableText] matches banned tokens.
void assertNoBannedTokensVisible(WidgetTester tester) {
  final List<String> hits = <String>[];
  for (final Text widget in tester.widgetList<Text>(find.byType(Text))) {
    final String? data = widget.data;
    if (data != null && textLooksBanned(data)) hits.add(data);
    final InlineSpan? span = widget.textSpan;
    if (span != null) {
      final String buffer = span.toPlainText();
      if (textLooksBanned(buffer)) hits.add(buffer);
    }
  }
  expect(
    hits,
    isEmpty,
    reason: 'Banned technical tokens visible in UI:\n${hits.join('\n')}',
  );
}
