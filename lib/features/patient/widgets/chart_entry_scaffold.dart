import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Frame for the chart-data screens: back button, title, scrolling body.
class ChartEntryScaffold extends StatelessWidget {
  const ChartEntryScaffold({
    required this.title,
    required this.child,
    this.bottom,
    this.onRefresh,
    this.patientName,
    this.room,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;

  /// Pinned under the body, for the main action.
  final Widget? bottom;

  /// Pull down to reload. Left out on screens that have nothing to reload.
  final Future<void> Function()? onRefresh;

  /// Optional sticky patient identity under the screen title.
  final String? patientName;
  final String? room;

  /// Optional header action (e.g. History).
  final Widget? trailing;

  Widget _body() {
    final Widget scroll = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: child,
    );
    final Future<void> Function()? refresh = onRefresh;
    return refresh == null
        ? scroll
        : RefreshIndicator(onRefresh: refresh, child: scroll);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    // Scaffold already shrinks for the keyboard — do not add viewInsets again
    // on the pinned bottom bar (that caused RenderFlex overflow).
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: colors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                              fontSize: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (patientName != null && patientName!.isNotEmpty)
                            Text(
                              [
                                patientName,
                                if (room != null && room!.trim().isNotEmpty)
                                  'Rm ${room!.trim()}',
                              ].join(' · '),
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
                    ?trailing,
                  ],
                ),
              ),
              Expanded(child: _body()),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a date and time. Returns null if the user cancels.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (date == null || !context.mounted) return null;
  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
