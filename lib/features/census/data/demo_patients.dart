import 'package:flutter/material.dart';

enum PatientStatus { critical, stable, reviewPending }

class CensusPatient {
  const CensusPatient({
    required this.id,
    required this.room,
    required this.name,
    required this.detail,
    required this.status,
    required this.updatedLabel,
    required this.mrn,
    required this.codeStatus,
    required this.summary,
    required this.accent,
    required this.icon,
    required this.ageSex,
    required this.hospitalDay,
    required this.problem,
    required this.keyFinding,
    required this.statusText,
    this.possibleDischarge = false,
  });

  final String id;
  final String room;
  final String name;

  /// Age and problem, for example `76 yrs · Acute decompensated heart failure`.
  final String detail;
  final PatientStatus status;
  final String updatedLabel;
  final String mrn;
  final String codeStatus;
  final String summary;
  final Color accent;
  final IconData icon;

  /// Short age and sex, for example `76F`.
  final String ageSex;

  /// Hospital day, for example `HD 3`.
  final int hospitalDay;

  /// Main problem shown on census cards.
  final String problem;

  /// One line from the chart that explains the card.
  final String keyFinding;

  /// Label shown in the census status pill.
  final String statusText;
  final bool possibleDischarge;

  /// `76F · 509A · HD 3`
  String get metaLine => '$ageSex · $room · HD $hospitalDay';

  String get statusLabel => statusText;

  String get initials {
    return name
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map((String part) => part[0])
        .take(2)
        .join();
  }
}

const List<CensusPatient> demoPatients = <CensusPatient>[
  CensusPatient(
    id: 'p-509a',
    room: '509A',
    name: 'Rosa Martinez',
    detail: '76 yrs · Acute decompensated heart failure',
    status: PatientStatus.critical,
    updatedLabel: 'Updated 9:36',
    mrn: '50901',
    codeStatus: 'Full Code',
    summary:
        '76-year-old woman with HFpEF and CKD admitted for acute decompensated heart failure. Oxygen need increased overnight, and creatinine rose from 1.2 to 1.7 during diuresis with low documented urine output. Today’s examination and plan are not entered.',
    accent: Color(0xFFE11D48),
    icon: Icons.favorite_rounded,
    ageSex: '76F',
    hospitalDay: 3,
    problem: 'Acute decompensated heart failure',
    keyFinding: 'O₂ increased overnight; creatinine 1.2 → 1.7',
    statusText: 'Needs early review',
  ),
  CensusPatient(
    id: 'p-412b',
    room: '412B',
    name: 'Daniel Brooks',
    detail: '64 yrs · Community-acquired pneumonia',
    status: PatientStatus.stable,
    updatedLabel: 'Updated 8:50',
    mrn: '41202',
    codeStatus: 'Full Code',
    summary:
        '64-year-old man admitted with community-acquired pneumonia. He is afebrile and his oxygen requirement decreased from 4 L to 2 L. Today’s examination and plan are not entered.',
    accent: Color(0xFF1F9D6A),
    icon: Icons.air_rounded,
    ageSex: '64M',
    hospitalDay: 2,
    problem: 'Community-acquired pneumonia',
    keyFinding: 'Afebrile; oxygen decreased 4 L → 2 L',
    statusText: 'Improving',
  ),
  CensusPatient(
    id: 'p-305c',
    room: '305C',
    name: 'Samuel Chen',
    detail: '58 yrs · Diabetic foot infection',
    status: PatientStatus.reviewPending,
    updatedLabel: 'Updated 8:15',
    mrn: '30503',
    codeStatus: 'Full Code',
    summary:
        '58-year-old man with a diabetic foot infection. The wound culture and the podiatry recommendations are still pending. Today’s examination and plan are not entered.',
    accent: Color(0xFFD97706),
    icon: Icons.medical_services_outlined,
    ageSex: '58M',
    hospitalDay: 5,
    problem: 'Diabetic foot infection',
    keyFinding: 'Awaiting wound culture and podiatry recommendations',
    statusText: 'Pending studies',
  ),
  CensusPatient(
    id: 'p-621a',
    room: '621A',
    name: 'Elena Ruiz',
    detail: '82 yrs · Complicated urinary tract infection',
    status: PatientStatus.stable,
    updatedLabel: 'Updated 7:40',
    mrn: '62104',
    codeStatus: 'Full Code',
    summary:
        '82-year-old woman with a complicated urinary tract infection. She is clinically improved, and the discharge medication review is open. Today’s plan is not entered.',
    accent: Color(0xFF2677D9),
    icon: Icons.home_rounded,
    ageSex: '82F',
    hospitalDay: 4,
    problem: 'Complicated urinary tract infection',
    keyFinding: 'Clinically improved; discharge medication review',
    statusText: 'Possible discharge',
    possibleDischarge: true,
  ),
];

CensusPatient? patientById(String id) {
  for (final CensusPatient patient in demoPatients) {
    if (patient.id == id) return patient;
  }
  return null;
}
