import 'package:flutter/foundation.dart';

class ChartTask {
  const ChartTask({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    this.due = 'Not entered',
    this.dueNow = false,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String title;

  /// Deadline text, for example `2:00 PM`. `Not entered` when nobody set one.
  final String due;
  final bool dueNow;
}

class RoundsPriority {
  const RoundsPriority({required this.title, required this.state});

  final String title;
  final String state;
}

class TeachItem {
  const TeachItem({
    required this.topic,
    required this.vignette,
    required this.leadIn,
    required this.options,
    required this.correctIndex,
    required this.correctExplanation,
    required this.distractorExplanations,
    required this.objective,
    required this.takeaway,
  });

  final String topic;
  final String vignette;
  final String leadIn;
  final List<String> options;
  final int correctIndex;
  final String correctExplanation;
  final List<String> distractorExplanations;
  final String objective;
  final String takeaway;
}

class PatientWorkspace {
  const PatientWorkspace({
    required this.patientId,
    required this.changes,
    required this.missing,
    required this.oneLiner,
    required this.oralDraft,
    required this.expandedReview,
    required this.priorities,
    required this.attendingQuestion,
    required this.attendingFramework,
    required this.evidenceTopic,
    required this.tasks,
    required this.signOut,
    required this.question,
    required this.pearl,
  });

  final String patientId;
  final List<String> changes;
  final List<String> missing;
  final String oneLiner;
  final String oralDraft;
  final List<String> expandedReview;
  final List<RoundsPriority> priorities;
  final String attendingQuestion;
  final List<String> attendingFramework;
  final String evidenceTopic;
  final List<ChartTask> tasks;
  final String signOut;
  final TeachItem question;

  /// Teaching-log card: category and title.
  final ({String category, String title, int cards}) pearl;
}

const List<PatientWorkspace> demoWorkspaces = <PatientWorkspace>[
  PatientWorkspace(
    patientId: 'p-509a',
    changes: <String>[
      'Oxygen need increased overnight.',
      'Creatinine rose from 1.2 to 1.7 during diuresis, with low documented urine output.',
    ],
    missing: <String>[
      'A measured oxygen flow is not stored.',
      'A urine output volume is not stored.',
      'Today’s examination and plan have not been entered.',
    ],
    oneLiner:
        '76-year-old woman with HFpEF and CKD admitted for ADHF, now with increasing oxygen requirements and worsening renal function during diuresis.',
    oralDraft:
        'Rosa Martinez is a 76-year-old woman with HFpEF and CKD, hospital day 3 for acute decompensated heart failure. Overnight her oxygen need increased, and creatinine rose from 1.2 to 1.7 during diuresis with low documented urine output. The oxygen flow, the urine volume, and today’s examination and plan are not in the chart, so those are not stated as known.',
    expandedReview: <String>[
      'Documented problem: acute decompensated heart failure with HFpEF and CKD.',
      'Documented change: oxygen need increased overnight.',
      'Documented change: creatinine 1.2 → 1.7 with low documented urine output.',
      'Not entered: today’s examination and clinician plan.',
    ],
    priorities: <RoundsPriority>[
      RoundsPriority(title: 'Reassess volume status', state: 'In progress'),
      RoundsPriority(title: 'Clarify urine output', state: 'Pending'),
      RoundsPriority(title: 'Review diuretic response', state: 'Pending'),
    ],
    attendingQuestion:
        'How would you distinguish cardiorenal syndrome from over-diuresis?',
    attendingFramework: <String>[
      'Start with volume status: neck veins, edema, orthopnea, lung findings, and the weight trend.',
      'Compare the direction of oxygen need with the direction of creatinine.',
      'Ask what is missing: measured urine output and today’s examination.',
      'State the clinician’s own plan separately from these considerations.',
    ],
    evidenceTopic: 'cardiorenal syndrome during diuresis for heart failure',
    tasks: <ChartTask>[
      ChartTask(
        id: 't-509a-urine',
        patientId: 'p-509a',
        patientName: 'Rosa Martinez',
        title: 'Clarify urine output with bedside RN',
        due: 'Due now',
        dueNow: true,
      ),
      ChartTask(
        id: 't-509a-bmp',
        patientId: 'p-509a',
        patientName: 'Rosa Martinez',
        title: 'Repeat BMP and reassess diuretic plan',
        due: '2:00 PM',
      ),
    ],
    signOut:
        'Rosa Martinez, room 509A, hospital day 3 for acute decompensated heart failure. Oxygen need increased overnight and creatinine rose from 1.2 to 1.7 with low documented urine output. A repeat BMP is planned. No contingency instruction is included until a clinician writes one.',
    question: TeachItem(
      topic: 'Cardiorenal syndrome versus over-diuresis',
      vignette:
          'A fictional 76-year-old woman with HFpEF and CKD is on day 3 of intravenous diuresis. Overnight her oxygen need increased and her creatinine rose from 1.2 to 1.7. Urine output is documented as low.',
      leadIn:
          'Which finding would best support persistent congestion rather than over-diuresis as the reason for the rising creatinine?',
      options: <String>[
        'Flat neck veins with dry mucous membranes and orthostatic dizziness.',
        'Elevated neck-vein pressure with leg edema and a rising oxygen need.',
        'Clear lungs on room air with a collapsed inferior vena cava.',
        'A large weight loss together with new low blood pressure.',
        'A new high sodium with a rising urea-to-creatinine ratio alone.',
      ],
      correctIndex: 1,
      correctExplanation:
          'Elevated venous pressure, edema, and a rising oxygen need point to ongoing congestion. Kidney function can worsen with venous congestion, so more fluid removal may be considered by the team after review.',
      distractorExplanations: <String>[
        'Flat neck veins and dry membranes suggest volume depletion.',
        'Clear lungs on room air and a collapsed vein suggest a low volume state.',
        'Large weight loss with low blood pressure suggests over-diuresis.',
        'A high sodium and urea ratio alone can reflect volume contraction and is not specific.',
      ],
      objective:
          'Use bedside volume findings to separate congestion from over-diuresis.',
      takeaway:
          'Read the volume examination first. Creatinine alone does not tell you the direction.',
    ),
    pearl: (
      category: 'CARDIORENAL SYNDROME',
      title: 'Distinguishing congestion from over-diuresis',
      cards: 2,
    ),
  ),
  PatientWorkspace(
    patientId: 'p-412b',
    changes: <String>[
      'Afebrile.',
      'Oxygen requirement decreased from 4 L to 2 L.',
    ],
    missing: <String>[
      'Oxygen support plan for the next 24 hours is not documented.',
      'Today’s examination has not been entered.',
      'Today’s clinician plan has not been entered.',
    ],
    oneLiner:
        '64-year-old man on hospital day 2 for community-acquired pneumonia, now afebrile with oxygen weaning from 4 L to 2 L.',
    oralDraft:
        'Daniel Brooks is a 64-year-old man on hospital day 2 for community-acquired pneumonia. He is afebrile, and his oxygen requirement decreased from 4 L to 2 L. Oxygen support goals, today’s examination, and today’s plan are not entered.',
    expandedReview: <String>[
      'Documented problem: community-acquired pneumonia.',
      'Documented change: afebrile; oxygen 4 L → 2 L.',
      'Unknown: oxygen support goals, today’s examination, and the clinician’s plan.',
    ],
    priorities: <RoundsPriority>[
      RoundsPriority(title: 'Reassess oxygen requirement', state: 'Pending'),
      RoundsPriority(title: 'Review antibiotic course', state: 'Pending'),
    ],
    attendingQuestion:
        'What findings would make you comfortable moving toward discharge?',
    attendingFramework: <String>[
      'Stable vital signs and no fever over the documented period.',
      'Oxygen need trending down toward the patient’s baseline.',
      'Able to take oral medication and fluids.',
      'A clear follow-up plan written by the team.',
    ],
    evidenceTopic: 'community-acquired pneumonia in adults',
    tasks: <ChartTask>[
      ChartTask(
        id: 't-412b-oxygen',
        patientId: 'p-412b',
        patientName: 'Daniel Brooks',
        title: 'Reassess oxygen requirement',
        due: '11:30 AM',
        dueNow: true,
      ),
    ],
    signOut:
        'Daniel Brooks, room 412B, hospital day 2 for community-acquired pneumonia. Afebrile, and oxygen decreased from 4 L to 2 L. No contingency instruction is included until a clinician writes one.',
    question: TeachItem(
      topic: 'Pneumonia — signs of clinical stability',
      vignette:
          'A fictional 64-year-old man is on day 2 of treatment for community-acquired pneumonia. He has been afebrile and his oxygen need dropped from 4 L to 2 L.',
      leadIn:
          'Which set of findings would most support clinical stability for moving toward discharge planning?',
      options: <String>[
        'New fever with a rising oxygen need.',
        'Stable vital signs, no fever, improving oxygenation, and able to take oral medication.',
        'A chest radiograph that has not yet fully cleared as the only finding.',
        'Inability to take oral fluids with a normal temperature.',
        'A falling oxygen saturation while the oxygen flow is increased.',
      ],
      correctIndex: 1,
      correctExplanation:
          'Stable vital signs, no fever, improving oxygenation, and oral intake together support clinical stability.',
      distractorExplanations: <String>[
        'New fever with more oxygen suggests worsening illness.',
        'A film that has not cleared yet is common, because the radiograph lags behind symptoms. It is not a marker of stability on its own.',
        'If the patient cannot take oral fluids, discharge readiness is not supported.',
        'Falling saturation despite more oxygen suggests worsening.',
      ],
      objective: 'Name the markers of clinical stability in pneumonia.',
      takeaway:
          'Stability is a group of findings. One normal value is not enough.',
    ),
    pearl: (
      category: 'INPATIENT MEDICINE',
      title: 'Markers of clinical stability in pneumonia',
      cards: 3,
    ),
  ),
  PatientWorkspace(
    patientId: 'p-305c',
    changes: <String>[
      'Wound culture is still pending.',
      'Podiatry recommendations are still pending.',
    ],
    missing: <String>[
      'The final wound culture result is not available.',
      'The podiatry recommendation is not documented.',
      'Today’s clinician plan has not been entered.',
    ],
    oneLiner:
        '58-year-old man on hospital day 5 for a diabetic foot infection, awaiting wound culture and podiatry recommendations.',
    oralDraft:
        'Samuel Chen is a 58-year-old man on hospital day 5 for a diabetic foot infection. The wound culture and the podiatry recommendations are pending, so the next step is not stated until they return. Today’s plan has not been entered.',
    expandedReview: <String>[
      'Documented problem: diabetic foot infection.',
      'Pending: final wound culture and podiatry recommendation.',
      'Unknown: today’s examination and clinician plan.',
    ],
    priorities: <RoundsPriority>[
      RoundsPriority(title: 'Follow final wound culture', state: 'Pending'),
      RoundsPriority(title: 'Confirm podiatry visit', state: 'Pending'),
    ],
    attendingQuestion:
        'When would you worry about osteomyelitis in a diabetic foot infection?',
    attendingFramework: <String>[
      'Exposed bone, or bone that can be probed to in the wound.',
      'A wound that is slow to heal or deep, or a large ulcer.',
      'Inflammatory markers that stay high.',
      'Ask which imaging or bone sample the team plans to obtain.',
    ],
    evidenceTopic: 'diabetic foot infection and osteomyelitis',
    tasks: <ChartTask>[
      ChartTask(
        id: 't-305c-culture',
        patientId: 'p-305c',
        patientName: 'Samuel Chen',
        title: 'Follow final wound culture',
        due: 'Before sign-out',
      ),
    ],
    signOut:
        'Samuel Chen, room 305C, hospital day 5 for a diabetic foot infection. Wound culture and podiatry recommendations are pending. No contingency instruction is included until a clinician writes one.',
    question: TeachItem(
      topic: 'Diabetic foot infection — deep infection',
      vignette:
          'A fictional 58-year-old man with diabetes has a foot ulcer. On examination the probe reaches bone. He has no fever.',
      leadIn: 'What is the best next consideration?',
      options: <String>[
        'Rely on a superficial swab as the only evidence of the organism.',
        'Assume there is no bone infection because he has no fever.',
        'Consider osteomyelitis and ask about imaging and involving podiatry or surgery.',
        'Stop evaluating until the culture is final.',
        'Reassure the patient because his blood glucose is normal.',
      ],
      correctIndex: 2,
      correctExplanation:
          'Bone that can be probed raises concern for bone infection. Absence of fever does not exclude it, and imaging and specialist input help decide the next step.',
      distractorExplanations: <String>[
        'A surface swab can grow organisms that are not the cause of a deep infection.',
        'Many patients with bone infection have no fever.',
        'Waiting with no evaluation can delay recognition of a deep infection.',
        'A normal glucose does not rule out a deep infection.',
      ],
      objective:
          'Recognize when a diabetic foot ulcer should prompt a search for bone infection.',
      takeaway:
          'Bone that can be probed should raise concern, even with no fever.',
    ),
    pearl: (
      category: 'INPATIENT MEDICINE',
      title: 'Diabetic foot infection and bone involvement',
      cards: 2,
    ),
  ),
  PatientWorkspace(
    patientId: 'p-621a',
    changes: <String>[
      'Clinically improved.',
      'Discharge medication review is open.',
    ],
    missing: <String>[
      'The discharge medication list has not been reconciled.',
      'Today’s clinician plan has not been entered.',
    ],
    oneLiner:
        '82-year-old woman on hospital day 4 for a complicated urinary tract infection, clinically improved and a possible discharge.',
    oralDraft:
        'Elena Ruiz is an 82-year-old woman on hospital day 4 for a complicated urinary tract infection. She is clinically improved, and the discharge medication review is open. Today’s plan has not been entered.',
    expandedReview: <String>[
      'Documented problem: complicated urinary tract infection.',
      'Documented: clinically improved; possible discharge.',
      'Open: discharge medication review and today’s plan.',
    ],
    priorities: <RoundsPriority>[
      RoundsPriority(
        title: 'Complete medication reconciliation',
        state: 'In progress',
      ),
      RoundsPriority(title: 'Confirm discharge readiness', state: 'Pending'),
    ],
    attendingQuestion:
        'What should a discharge medication review cover for an older adult?',
    attendingFramework: <String>[
      'Compare the final culture result with the antibiotic being continued.',
      'Check kidney function against each medication.',
      'Reconcile the home medication list for duplicates and interactions.',
      'Write who will follow up and when.',
    ],
    evidenceTopic: 'complicated urinary tract infection in older adults',
    tasks: <ChartTask>[
      ChartTask(
        id: 't-621a-medrec',
        patientId: 'p-621a',
        patientName: 'Elena Ruiz',
        title: 'Complete medication reconciliation',
        due: '12:00 PM',
      ),
    ],
    signOut:
        'Elena Ruiz, room 621A, hospital day 4 for a complicated urinary tract infection. Clinically improved; discharge medication review is open. No contingency instruction is included until a clinician writes one.',
    question: TeachItem(
      topic: 'Discharge medication review',
      vignette:
          'A fictional 82-year-old woman is clinically improved after treatment for a complicated urinary tract infection and may go home soon.',
      leadIn:
          'What is the most important part of the discharge medication review?',
      options: <String>[
        'Copy the admission list without changes.',
        'Check the final culture result, kidney function, and the home medication list for duplicates and interactions.',
        'Skip the review because she is improved.',
        'Continue every inpatient medication at home.',
        'Ask the patient to bring the medication list to a later visit.',
      ],
      correctIndex: 1,
      correctExplanation:
          'A review that checks the culture, kidney function, and the full medication list catches problems before discharge.',
      distractorExplanations: <String>[
        'Copying without review can carry forward errors.',
        'Improvement does not remove the need for reconciliation.',
        'Many inpatient medications are not meant to continue at home.',
        'Delaying the review lets problems reach the patient.',
      ],
      objective: 'List what a discharge medication review should check.',
      takeaway:
          'Reconcile against the culture, kidney function, and home list.',
    ),
    pearl: (
      category: 'INPATIENT MEDICINE',
      title: 'Discharge medication reconciliation',
      cards: 4,
    ),
  ),
];

PatientWorkspace? workspaceFor(String patientId) {
  for (final PatientWorkspace workspace in demoWorkspaces) {
    if (workspace.patientId == patientId) return workspace;
  }
  return null;
}

/// Tasks for this demo session: the seeded list plus anything added on rounds.
List<ChartTask> get allDemoTasks {
  return <ChartTask>[
    ...demoWorkspaces.expand((PatientWorkspace item) => item.tasks),
    ...DemoTaskBoard.added,
  ];
}

/// Task state for this demo session. Completing a task does not write an order.
class DemoTaskBoard {
  DemoTaskBoard._();

  /// Bumps whenever a task is added or completed so screens can rebuild.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static final Set<String> _done = <String>{'t-621a-medrec'};
  static final List<ChartTask> added = <ChartTask>[];

  static bool isDone(String taskId) => _done.contains(taskId);

  static void toggle(String taskId) {
    if (!_done.remove(taskId)) _done.add(taskId);
    changes.value++;
  }

  static void add(ChartTask task) {
    added.add(task);
    changes.value++;
  }

  /// Back to the seeded list. Used by tests. It does not notify listeners,
  /// so call it before a screen is built.
  @visibleForTesting
  static void reset() {
    _done
      ..clear()
      ..add('t-621a-medrec');
    added.clear();
  }
}
