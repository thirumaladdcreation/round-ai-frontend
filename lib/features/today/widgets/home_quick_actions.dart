import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_patient_sheet.dart';
import 'package:round_ai/features/today/widgets/home_section_title.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';

bool _notes() => AppFeatures.notes;
bool _presentation() => AppFeatures.presentation;
bool _evidence() => AppFeatures.evidence;
bool _teach() => AppFeatures.teach;

class HomeQuickAction {
  const HomeQuickAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.pathFor,
    required this.available,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String Function(String patientId) pathFor;

  /// False while the backend does not support this action.
  final bool Function() available;
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  static const List<HomeQuickAction> actions = <HomeQuickAction>[
    HomeQuickAction(
      icon: Icons.note_alt_outlined,
      title: 'Draft a Note',
      detail: 'Open the note for one patient',
      pathFor: AppRoutes.notePath,
      available: _notes,
    ),
    HomeQuickAction(
      icon: Icons.co_present_outlined,
      title: 'Prepare Presentation',
      detail: 'Review the oral draft',
      pathFor: AppRoutes.presentationPath,
      available: _presentation,
    ),
    HomeQuickAction(
      icon: Icons.menu_book_outlined,
      title: 'Explore Evidence',
      detail: 'Open the evidence topic',
      pathFor: AppRoutes.evidencePath,
      available: _evidence,
    ),
    HomeQuickAction(
      icon: Icons.school_outlined,
      title: 'Teach Me',
      detail: 'Practice from this chart',
      pathFor: AppRoutes.teachPath,
      available: _teach,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<HomeQuickAction> shown = actions
        .where((HomeQuickAction action) => action.available())
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const HomeSectionTitle(title: 'AI quick actions'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: shown
              .map(
                (HomeQuickAction action) => HomeQuickActionTile(
                  action: action,
                  patients: snapshot.patients,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class HomeQuickActionTile extends StatelessWidget {
  const HomeQuickActionTile({
    required this.action,
    required this.patients,
    super.key,
  });

  final HomeQuickAction action;
  final List<HomePatientPreview> patients;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return HomeSurface(
      onTap: () => _open(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(action.icon, size: 20, color: colors.primary),
          const Spacer(),
          Text(
            action.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.semiBold(fontSize: 14, color: colors.navy),
          ),
          const SizedBox(height: 2),
          Text(
            action.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (patients.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No assigned patient'),
            content: const Text(
              'Choose a team with patients before opening this action.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
      return;
    }
    final String? patientId = await HomePatientSheet.show(context, patients);
    if (patientId == null || !context.mounted) return;
    context.push(action.pathFor(patientId));
  }
}
