import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/notes/models/note_section.dart';

void main() {
  test('NoteContent parses scribe sentences, spans, and needs_clarification', () {
    final AiEnvelope envelope = AiEnvelope.fromBody(<String, Object?>{
      'artifact_id': 'a1',
      'operation': 'draft_note:progress',
      'status': 'draft',
      'review_state': 'draft',
      'requires_review': true,
      'content': <String, Object?>{
        'scribe_mode': 'from_dictation',
        'transcript': 'fever last night no chest pain',
        'needs_clarification': <Object>[
          <String, Object?>{
            'phrase': 'ICU console',
            'question': 'What was placed?',
            'spans': <Object>[
              <String, Object?>{'start': 0, 'end': 11},
            ],
          },
        ],
        'sections': <Object>[
          <String, Object?>{
            'key': 'subjective',
            'title': 'Subjective',
            'text': 'Fever last night. No chest pain.',
            'fact_ids': <Object>[],
            'flags': <Object>[],
            'sentences': <Object>[
              <String, Object?>{
                'text': 'Fever last night.',
                'spans': <Object>[
                  <String, Object?>{'start': 0, 'end': 16},
                ],
                'fact_ids': <Object>[],
              },
            ],
          },
        ],
      },
    });

    final NoteContent content = NoteContent.fromEnvelope(envelope);
    expect(content.scribeMode, isTrue);
    expect(content.transcript, contains('fever'));
    expect(content.needsClarification, hasLength(1));
    expect(content.needsClarification.first.question, contains('placed'));
    expect(content.sections.first.sentences, hasLength(1));
    expect(content.sections.first.sentences.first.spans.first.start, 0);
  });
}
