import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

/// Spaced-review queue (1 / 3 / 7 day intervals).
class SpacedReviewScreen extends StatefulWidget {
  const SpacedReviewScreen({this.repository, super.key});

  final TeachingRepository? repository;

  @override
  State<SpacedReviewScreen> createState() => _SpacedReviewScreenState();
}

class _SpacedReviewScreenState extends State<SpacedReviewScreen> {
  bool _loading = true;
  String? _error;
  List<ReviewQueueItem> _items = const <ReviewQueueItem>[];

  TeachingRepository get _repo {
    if (widget.repository != null) return widget.repository!;
    try {
      return InjectionContainer.instance.teachingRepository;
    } catch (_) {
      return DemoTeachingRepository();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final Result<List<ReviewQueueItem>> result = await _repo.loadReviewQueue();
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok<List<ReviewQueueItem>>(:final List<ReviewQueueItem> value):
        setState(() => _items = value);
      case Err<List<ReviewQueueItem>>(:final Failure failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Review queue')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_error!),
                  const SizedBox(height: 12),
                  AppButton(label: 'Try again', onPressed: _load),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  Text(
                    'Missed approved questions appear here immediately, then follow 1 / 3 / 7 day spacing after you answer again.',
                    style: AppTypography.regular(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty) ...<Widget>[
                    Text(
                      'Nothing is due right now. Open Elevated Pulse, answer incorrectly once, then return here to retry.',
                      style: AppTypography.regular(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Practice Elevated Pulse',
                      onPressed: () => context.push(
                        AppRoutes.topicQuizPath('Elevated Pulse'),
                      ),
                    ),
                  ] else
                    ..._items.map(
                      (ReviewQueueItem item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.topic,
                          style: AppTypography.semiBold(
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(item.stageLabel),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          AppRoutes.topicQuizPath(item.topic),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
