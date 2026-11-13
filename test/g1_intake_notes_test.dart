import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/notes/models/note_section.dart';
import 'package:round_ai/features/notes/models/note_template.dart';
import 'package:round_ai/features/notes/repository/notes_repository_impl.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository_impl.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SectionSource clinician_*', () {
    test('maps backend source strings to typed fields', () {
      expect(
        SectionSource.parse('clinician_history'),
        SectionSource.history,
      );
      expect(SectionSource.parse('clinician_exam'), SectionSource.exam);
      expect(SectionSource.parse('clinician_plan'), SectionSource.plan);
      expect(
        SectionSource.parse('clinician_subjective'),
        SectionSource.clinicianSubjective,
      );
      expect(SectionSource.parse('clinician_update'), SectionSource.update);
      expect(SectionSource.parse('clinician_support'), SectionSource.support);
      expect(SectionSource.parse('facts_and_exam'), SectionSource.facts);
      expect(SectionSource.history.wireField, 'history');
      expect(SectionSource.plan.wireField, 'plan');
    });

    test('admit_hp history sections are each typed', () {
      final NoteTemplate t = NoteTemplate.fromJson(<String, dynamic>{
        'key': 'admit_hp',
        'title': 'Admission H&P',
        'sections': <Object>[
          for (final (String key, String title) in historyFields)
            <String, Object>{
              'key': key,
              'title': title,
              'source': 'clinician_history',
            },
          <String, Object>{
            'key': 'exam',
            'title': 'Exam',
            'source': 'clinician_exam',
          },
          <String, Object>{
            'key': 'data',
            'title': 'Data',
            'source': 'facts',
          },
          <String, Object>{
            'key': 'assessment_plan',
            'title': 'Assessment and Plan',
            'source': 'clinician_plan',
          },
        ],
      });
      expect(t.typedSections, hasLength(10));
      expect(
        t.typedSections
            .where((TemplateSection s) => s.source == SectionSource.history)
            .map((TemplateSection s) => s.key),
        historyFields.map(((String, String) f) => f.$1),
      );
    });
  });

  group('notes generate body', () {
    test('sends flat fields plus inputs_from_source_ids', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{
          'artifact_id': 'n1',
          'operation': 'draft_note',
          'patient_id': 'p1',
          'context_revision': 1,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'created_at': '2026-11-13T00:00:00Z',
          'content': <String, Object>{
            'sections': <Object>[],
            'fed_from_sources': <Object>[
              <String, Object>{
                'source_id': 'src1',
                'field': 'hpi',
                'kind': 'dictation',
              },
            ],
          },
        }),
      );
      final NotesRepositoryImpl repo = NotesRepositoryImpl(await _client(a));
      final Result<AiEnvelope> r = await repo.generate(
        'p1',
        noteType: 'admit_hp',
        inputs: <String, Object>{
          'exam': 'Clear lungs',
          'history': <String, String>{'chief_complaint': 'Dyspnea'},
        },
        inputsFromSourceIds: const <String>['src1'],
        applyTo: const <String>['hpi'],
        idempotencyKey: 'k-g1',
      );
      expect((r as Ok<AiEnvelope>).value.artifactId, 'n1');
      final NoteContent content = NoteContent.fromEnvelope(r.value);
      expect(content.fedFromSources, hasLength(1));
      expect(content.fedFromSources.first.field, 'hpi');
      expect(a.requests.single.data, <String, Object>{
        'note_type': 'admit_hp',
        'exam': 'Clear lungs',
        'history': <String, String>{'chief_complaint': 'Dyspnea'},
        'inputs_from_source_ids': <String>['src1'],
        'apply_to': <String>['hpi'],
      });
      expect(a.requests.single.headers[IdempotencyKey.header], 'k-g1');
    });
  });

  group('intake models', () {
    test('parses intake and transcribe replies', () {
      final IntakeResult intake = IntakeResult.fromJson(<String, dynamic>{
        'source_id': 's9',
        'transcript_or_text': 'HPI draft',
        'fact_ids': <String>['f1', 'f2'],
        'low_legibility_lines': <String>['blurry'],
        'confidence': 'ok',
      });
      expect(intake.sourceId, 's9');
      expect(intake.text, 'HPI draft');
      expect(intake.pendingFactCount, 2);

      final TranscribeResult t = TranscribeResult.fromJson(<String, dynamic>{
        'text': 'Feels better',
        'model': 'whisper',
      });
      expect(t.text, 'Feels better');
    });
  });

  group('chart sources list', () {
    test('reads bare array and tags dictation kinds', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <Object>[
          <String, Object>{
            'id': 'd1',
            'kind': 'dictation',
            'title': 'Dictation',
            'event_time': '2026-11-13T01:00:00Z',
          },
          <String, Object>{
            'id': 'i1',
            'kind': 'image_extract',
            'title': 'Image extract',
          },
          <String, Object>{
            'id': 'n1',
            'kind': 'progress_note',
            'title': 'Note',
          },
        ]),
      );
      final Result<List<ChartSource>> r = await ChartDataRepositoryImpl(
        await _client(a),
      ).listSources('p1');
      final List<ChartSource> list = (r as Ok<List<ChartSource>>).value;
      expect(list, hasLength(3));
      expect(list[0].kind.feedsNotes, isTrue);
      expect(list[1].kind.feedsNotes, isTrue);
      expect(list[2].kind.feedsNotes, isFalse);
    });
  });
}
