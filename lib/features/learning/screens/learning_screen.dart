import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/external_link.dart';
import 'package:round_ai/core/utils/hospital_clock.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Learn tab: census-derived topics (no patient names), quiz, reads, guidelines.
class LearningScreen extends StatefulWidget {
  const LearningScreen({this.repository, super.key});

  final TeachingRepository? repository;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  bool _loading = true;
  String? _error;
  TeachingPlan? _plan;
  GuidelineUpdatesFeed? _guidelines;
  final TextEditingController _filter = TextEditingController();
  String _filterText = '';

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
    _filter.addListener(() {
      final String next = _filter.text.trim().toLowerCase();
      if (next == _filterText) return;
      setState(() => _filterText = next);
    });
    _load();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<TeachingTopic> get _filteredTopics {
    final List<TeachingTopic> topics = _plan?.topics ?? const <TeachingTopic>[];
    if (_filterText.isEmpty) return topics;
    return topics
        .where(
          (TeachingTopic t) =>
              t.topic.toLowerCase().contains(_filterText) ||
              t.topicKey.contains(_filterText),
        )
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final Result<TeachingPlan> plan = await _repo.loadPlan(
      date: HospitalClock.todayIsoDate(),
    );
    final Result<GuidelineUpdatesFeed> guidelines =
        await _repo.loadGuidelineUpdates();
    if (!mounted) return;
    setState(() => _loading = false);
    switch (plan) {
      case Ok<TeachingPlan>(:final TeachingPlan value):
        setState(() => _plan = value);
      case Err<TeachingPlan>(:final Failure failure):
        setState(() => _error = failure.message);
    }
    if (guidelines case Ok<GuidelineUpdatesFeed>(:final GuidelineUpdatesFeed value)) {
      setState(() => _guidelines = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final TeachingPlan? plan = _plan;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      AppButton(label: 'Try again', onPressed: _load),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: <Widget>[
                    Text(
                      'LEARN',
                      style: AppTypography.semiBold(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today’s topics',
                      style: AppTypography.bold(
                        fontSize: 28,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generic topics from confirmed and differential problems on your census. No patient names.',
                      style: AppTypography.regular(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (HospitalClock.demoMode ||
                        (HospitalClock.runtimeDemoClockIso?.isNotEmpty ??
                            false)) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Demo clock · ${HospitalClock.todayIsoDate()}',
                        style: AppTypography.medium(
                          fontSize: 12,
                          color: colors.warning,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.learningReviewQueue),
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: const Text('Spaced review queue'),
                      ),
                    ),
                    if (plan != null && plan.topics.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _filter,
                        decoration: appInputDecoration(
                          context,
                          label: 'Filter topics',
                          hint: 'Search by topic name',
                        ).copyWith(
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (plan == null || plan.topics.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'No teaching topics yet. Confirm or mark differential '
                              'problems on a patient chart — Learn builds generic '
                              'topics from the census (no patient names).',
                              style: AppTypography.regular(
                                fontSize: 13,
                                height: 1.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              label: 'Practice Elevated Pulse bank',
                              onPressed: () => context.push(
                                AppRoutes.topicQuizPath('Elevated Pulse'),
                              ),
                              expand: false,
                            ),
                          ],
                        ),
                      )
                    else if (_filteredTopics.isEmpty)
                      Text(
                        'No topics match “${_filter.text.trim()}”.',
                        style: AppTypography.regular(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      ..._filteredTopics.map(
                        (TeachingTopic t) => _TopicTile(topic: t),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Guideline updates',
                      style: AppTypography.semiBold(
                        fontSize: 17,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify against the source',
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_guidelines == null || _guidelines!.updates.isEmpty)
                      Text(
                        'No approved guideline updates for your census topics.',
                        style: AppTypography.regular(
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      ..._guidelines!.updates.map(
                        (TeachingReadItem u) => _GuidelineTile(item: u),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final TeachingTopic topic;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            topic.topic,
            style: AppTypography.semiBold(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            topic.countLabel,
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.topicQuizPath(topic.topic)),
                  icon: const Icon(Icons.quiz_outlined, size: 18),
                  label: const Text('Quiz'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.topicReadsPath(topic.topic)),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Reads'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuidelineTile extends StatelessWidget {
  const _GuidelineTile({required this.item});

  final TeachingReadItem item;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title,
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            <String>[
              if (item.organization.isNotEmpty) item.organization,
              if (item.publishedDate.isNotEmpty) item.publishedDate,
              if (item.date.isNotEmpty && item.publishedDate.isEmpty) item.date,
            ].join(' · '),
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          if (item.whyItMatters.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              item.whyItMatters,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            item.verify.isNotEmpty
                ? item.verify
                : 'Verify against the source',
            style: AppTypography.semiBold(fontSize: 12, color: colors.warning),
          ),
          if (item.externalUri != null)
            TextButton(
              onPressed: () => openExternally(item.externalUri!),
              child: const Text('Open source'),
            ),
        ],
      ),
    );
  }
}
