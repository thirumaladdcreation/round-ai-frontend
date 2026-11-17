import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Sticky patient name + room for patient-specific screens.
class PatientChrome extends StatelessWidget {
  const PatientChrome({
    required this.title,
    required this.patientName,
    required this.room,
    required this.child,
    this.actions = const <Widget>[],
    this.bottom,
    super.key,
  });

  final String title;
  final String patientName;
  final String room;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String identity = room.trim().isEmpty
        ? patientName
        : '$patientName · Rm $room';
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTypography.semiBold(
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          identity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.regular(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet: dictate, photo, or paste/manual fact under one Add update action.
Future<void> showAddUpdateSheet(BuildContext context, String patientId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) {
      final AppColors colors = AppColors.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Add update',
                style: AppTypography.semiBold(
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dictate, photograph, or enter chart text. Review extracted facts before they enter the summary.',
                style: AppTypography.regular(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.mic_none_rounded),
                title: const Text('Dictate'),
                onTap: () {
                  Navigator.pop(sheet);
                  context.push('/patient/$patientId/intake/dictate');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Photo of chart'),
                onTap: () {
                  Navigator.pop(sheet);
                  context.push('/patient/$patientId/intake/photo');
                },
              ),
              ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Paste or type text'),
                onTap: () {
                  Navigator.pop(sheet);
                  context.push('/patient/$patientId/sources/new');
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add a fact manually'),
                onTap: () {
                  Navigator.pop(sheet);
                  context.push('/patient/$patientId/facts/new');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
