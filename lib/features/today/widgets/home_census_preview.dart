import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/sync/patient_status_store.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

/// Recent patients — one shared card (header + rows), matching home mockup.
class HomeCensusPreview extends StatelessWidget {
  const HomeCensusPreview({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  static const int _previewLimit = 4;

  List<HomePatientPreview> _overlay(List<HomePatientPreview> patients) {
    PatientStatusStore? store;
    try {
      store = InjectionContainer.instance.patientStatusStore;
    } catch (_) {
      return patients;
    }
    return patients.map((HomePatientPreview p) {
      final PatientStatusSnapshot? snap = store!.get(p.id);
      if (snap == null) return p;
      return p.copyWith(
        pendingFacts: snap.unreviewedFacts,
        pendingTasks: snap.openTasks,
        noteStatus: snap.summaryState.isEmpty ? null : snap.summaryState,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    PatientStatusStore? store;
    try {
      store = InjectionContainer.instance.patientStatusStore;
    } catch (_) {}

    Widget body(List<HomePatientPreview> all) {
      final List<HomePatientPreview> preview =
          all.take(_previewLimit).toList(growable: false);
      return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.navy.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.groups_rounded,
                      size: 22,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Patients',
                        style: AppTypography.semiBold(
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.census),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF0A8F9C),
                      ),
                      child: Text(
                        'View All →',
                        style: AppTypography.semiBold(
                          fontSize: 13,
                          color: const Color(0xFF0A8F9C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (preview.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Text(
                    'No patients are assigned to this team.',
                    style: AppTypography.regular(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                for (int i = 0; i < preview.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 14,
                      endIndent: 14,
                      color: colors.border.withValues(alpha: 0.85),
                    ),
                  HomePatientTile(patient: preview[i]),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _NeedSomethingBanner(hasAttention: snapshot.attention.isNotEmpty),
      ],
    );
    }

    if (store == null) {
      return body(snapshot.patients);
    }
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? _) {
        return body(_overlay(snapshot.patients));
      },
    );
  }
}

class HomePatientTile extends StatelessWidget {
  const HomePatientTile({required this.patient, super.key});

  final HomePatientPreview patient;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String roomLine = <String>[
      if (patient.room.isNotEmpty) 'Rm ${patient.room}',
      if (patient.genderLabel != null) patient.genderLabel!,
      if (patient.ageLabel != null) patient.ageLabel!,
    ].join(' • ');
    final _StatusChip chip = _statusChip(colors);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.patientPath(patient.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _PatientAvatar(name: patient.name, indexHint: patient.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.semiBold(
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (roomLine.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        roomLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.regular(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    chip,
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textPrimary.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusChip _statusChip(AppColors colors) {
    final String note = patient.noteStatus.trim().toLowerCase();
    if (note.contains('not generated')) {
      return _StatusChip(
        label: 'Not generated',
        background: colors.criticalBg,
        foreground: colors.critical,
        icon: Icons.error_outline_rounded,
      );
    }
    if (note.contains('draft')) {
      return _StatusChip(
        label: 'In Progress',
        background: const Color(0xFFE8F3FF),
        foreground: colors.primary,
        icon: Icons.timelapse_rounded,
      );
    }
    if (note.contains('outdated')) {
      return _StatusChip(
        label: 'Outdated',
        background: colors.warningSoft,
        foreground: colors.warning,
        icon: Icons.schedule_rounded,
      );
    }
    if (note.contains('reviewed') || note.contains('ready')) {
      return _StatusChip(
        label: 'Ready for rounds',
        background: colors.successSoft,
        foreground: colors.success,
        icon: Icons.check_circle_rounded,
      );
    }
    if (note.isNotEmpty) {
      return _StatusChip(
        label: patient.noteStatus.trim(),
        background: colors.chipIdle,
        foreground: colors.textSecondary,
        icon: Icons.info_outline,
      );
    }
    return _StatusChip(
      label: 'Ready for rounds',
      background: colors.successSoft,
      foreground: colors.success,
      icon: Icons.check_circle_rounded,
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.name, required this.indexHint});

  final String name;
  final String indexHint;

  @override
  Widget build(BuildContext context) {
    final bool useIcon = indexHint.hashCode.isEven;
    final Color bg = useIcon
        ? const Color(0xFFD6E8FF)
        : const Color(0xFFD6F3F6);
    final Color fg = useIcon
        ? const Color(0xFF1B4F8A)
        : const Color(0xFF0A8F9C);

    return CircleAvatar(
      radius: 22,
      backgroundColor: bg,
      child: useIcon
          ? Icon(Icons.person_rounded, color: fg, size: 24)
          : Text(
              _initials(name),
              style: AppTypography.semiBold(fontSize: 13, color: fg),
            ),
    );
  }

  String _initials(String value) {
    final List<String> parts = value
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.semiBold(fontSize: 11, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Soft “Need something?” strip under recent patients (mockup).
/// Always a light card — ink stays dark even in app dark mode.
class _NeedSomethingBanner extends StatelessWidget {
  const _NeedSomethingBanner({required this.hasAttention});

  final bool hasAttention;

  static const Color _ink = Color(0xFF15252F);
  static const Color _muted = Color(0xFF5B6B7A);
  static const Color _accent = Color(0xFF0A8F9C);

  @override
  Widget build(BuildContext context) {
    final String detail = hasAttention
        ? 'Open a patient chart to clear what’s waiting.'
        : 'Nothing is waiting on this list.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFFE8F7F9),
            Color(0xFFD4F0F4),
          ],
        ),
        border: Border.all(color: const Color(0xFFB8E0E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 20,
              color: _accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Need something?',
                  style: AppTypography.semiBold(
                    fontSize: 14,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTypography.regular(
                    fontSize: 12.5,
                    height: 1.35,
                    color: _muted,
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

class HomeEmptyLine extends StatelessWidget {
  const HomeEmptyLine({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Text(
      message,
      style: AppTypography.regular(fontSize: 14, color: colors.textSecondary),
    );
  }
}
