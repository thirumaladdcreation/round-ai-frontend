import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// A team the signed-in clinician is allowed to open.
class ClinicalTeam extends Equatable {
  const ClinicalTeam({
    required this.id,
    required this.name,
    required this.unit,
    required this.patientCount,
    required this.icon,
    required this.tint,
  });

  /// From `GET /me`. Icon and color are picked by position, because the
  /// backend does not send them. A missing unit or count stays blank or 0.
  factory ClinicalTeam.fromJson(Map<String, dynamic> json, {int index = 0}) {
    const List<IconData> icons = <IconData>[
      Icons.medical_services_outlined,
      Icons.monitor_heart_outlined,
      Icons.favorite_border_rounded,
      Icons.content_cut_rounded,
    ];
    const List<Color> tints = <Color>[
      Color(0xFF4A9EFF),
      Color(0xFF39B8AD),
      Color(0xFFE11D48),
      Color(0xFF6D28D9),
    ];
    final Object? count = json['patient_count'];
    return ClinicalTeam(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      patientCount: count is num ? count.toInt() : 0,
      icon: icons[index % icons.length],
      tint: tints[index % tints.length],
    );
  }

  final String id;
  final String name;

  /// Service label shown on the card, such as Team A.
  final String unit;
  final int patientCount;
  final IconData icon;
  final Color tint;

  @override
  List<Object> get props => <Object>[id, name, unit, patientCount];
}

/// Demo assignment for Dr. Rivera. Teams outside this list are not shown.
const List<ClinicalTeam> demoTeams = <ClinicalTeam>[
  ClinicalTeam(
    id: 'internal-medicine',
    name: 'Internal Medicine',
    unit: 'Team A',
    patientCount: 12,
    icon: Icons.medical_services_outlined,
    tint: Color(0xFF4A9EFF),
  ),
  ClinicalTeam(
    id: 'icu',
    name: 'ICU Team',
    unit: 'Team B',
    patientCount: 8,
    icon: Icons.monitor_heart_outlined,
    tint: Color(0xFF39B8AD),
  ),
  ClinicalTeam(
    id: 'cardiology',
    name: 'Cardiology Team',
    unit: 'Team C',
    patientCount: 10,
    icon: Icons.favorite_border_rounded,
    tint: Color(0xFFE11D48),
  ),
  ClinicalTeam(
    id: 'surgery',
    name: 'Surgery Team',
    unit: 'Team D',
    patientCount: 10,
    icon: Icons.content_cut_rounded,
    tint: Color(0xFF6D28D9),
  ),
];

ClinicalTeam? teamById(String? id) {
  for (final ClinicalTeam team in demoTeams) {
    if (team.id == id) return team;
  }
  return null;
}
