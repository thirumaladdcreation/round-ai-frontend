import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/utils/clinical_format.dart';
import 'package:round_ai/features/notes/models/note_template.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'support/banned_tokens.dart';

void main() {
  group('clinical_format', () {
    test('humanizes clinician_plan', () {
      expect(
        humanizeMissingToken('clinician_plan'),
        "Today's Assessment and Plan not entered",
      );
    });

    test('note humanizeKey uses clinical copy for clinician_plan', () {
      expect(humanizeKey('clinician_plan'), isNot(contains('clinician_')));
      expect(humanizeKey('clinician_plan'), contains('Assessment and Plan'));
    });

    test('formats scalar trend into a sentence', () {
      expect(
        formatTrendMap(<String, dynamic>{
          'label': 'Creatinine',
          'from': 0.9,
          'to': 2.1,
          'unit': 'mg/dL',
          'direction': 'up',
          'delta': 1.2,
        }),
        'Creatinine increased from 0.9 to 2.1 mg/dL',
      );
    });

    test('formats nested from/to trend maps', () {
      expect(
        formatTrendMap(<String, dynamic>{
          'label': 'Creatinine',
          'from': <String, Object>{'value': '0.9'},
          'to': <String, Object>{'value': '2.1'},
          'unit': 'mg/dL',
          'direction': 'increased',
        }),
        'Creatinine increased from 0.9 to 2.1 mg/dL',
      );
    });

    test('formats value conflicts with values and source count', () {
      final String line = formatConflictMap(<String, dynamic>{
        'type': 'value_conflict',
        'label': 'Sodium',
        'values': <Object>['132', '145'],
        'fact_ids': <Object>[
          'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'ffffffff-1111-2222-3333-444444444444',
        ],
      });
      expect(line, contains('Sodium has conflicting values: 132 vs 145.'));
      expect(line, contains('2 linked chart facts'));
      expect(line, isNot(contains('aaaaaaaa')));
    });

    test('InsightItem never surfaces wire keys', () {
      final InsightItem item = InsightItem.fromJson(<String, dynamic>{
        'label': 'Creatinine',
        'unit': 'mg/dL',
        'delta': 1.2,
        'direction': 'rose',
        'from': 0.9,
        'to': 2.1,
      });
      expect(item.text, 'Creatinine increased from 0.9 to 2.1 mg/dL');
      expect(item.label, isEmpty);
      expect(item.text.toLowerCase(), isNot(contains('delta')));
      expect(item.text.toLowerCase(), isNot(contains('direction')));
    });
  });

  testWidgets('Patient/Today/Note surfaces hide banned technical tokens', (
    WidgetTester tester,
  ) async {
    final InsightItem trend = InsightItem.fromJson(<String, dynamic>{
      'label': 'Creatinine',
      'unit': 'mg/dL',
      'delta': 1.2,
      'direction': 'up',
      'from': 0.9,
      'to': 2.1,
      'fact_ids': <String>['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              Text(humanizeMissingToken('clinician_plan')),
              Text(trend.text),
              Text(humanizeKey('clinician_exam')),
            ],
          ),
        ),
      ),
    );
    assertNoBannedTokensVisible(tester);
  });
}
