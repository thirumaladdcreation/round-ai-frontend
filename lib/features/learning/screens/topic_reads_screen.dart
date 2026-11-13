import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/external_link.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class TopicReadsScreen extends StatefulWidget {
  const TopicReadsScreen({
    required this.topic,
    this.repository,
    super.key,
  });

  final String topic;
  final TeachingRepository? repository;

  @override
  State<TopicReadsScreen> createState() => _TopicReadsScreenState();
}

class _TopicReadsScreenState extends State<TopicReadsScreen> {
  bool _loading = true;
  String? _error;
  TeachingReads? _reads;

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
    final Result<TeachingReads> result = await _repo.loadReads(
      topic: widget.topic,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok<TeachingReads>(:final TeachingReads value):
        setState(() => _reads = value);
      case Err<TeachingReads>(:final Failure failure):
        setState(() => _error = failure.message);
    }
  }

  Future<void> _open(TeachingReadItem item) async {
    final Uri? uri = item.externalUri;
    if (uri == null) return;
    final bool ok = await openExternally(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  Future<void> _save(TeachingReadItem item) async {
    if (!item.canSaveToReadingList) return;
    final Result<void> result = await _repo.saveToReadingList(
      pmid: item.pmid,
      title: item.title,
    );
    if (!mounted) return;
    switch (result) {
      case Ok<void>():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to reading list.')),
        );
      case Err<void>(:final Failure failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final TeachingReads? reads = _reads;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text('Reads · ${widget.topic}')),
      body: _loading
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  if (reads?.note.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        reads!.note,
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  if (reads?.retrievalError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Evidence search failed for some sections.',
                        style: AppTypography.regular(color: colors.warning),
                      ),
                    ),
                  _Section(
                    title: 'Recent studies',
                    items: reads?.recent ?? const <TeachingReadItem>[],
                    onOpen: _open,
                    onSave: _save,
                  ),
                  _Section(
                    title: 'Older high-design evidence',
                    items: reads?.olderHighDesign ?? const <TeachingReadItem>[],
                    onOpen: _open,
                    onSave: _save,
                  ),
                  _Section(
                    title: 'Guidelines',
                    items:
                        reads?.guidelinesPubmed ?? const <TeachingReadItem>[],
                    onOpen: _open,
                    onSave: _save,
                  ),
                  _Section(
                    title: curatedHighYieldLabel,
                    items:
                        reads?.curatedHighYield ?? const <TeachingReadItem>[],
                    onOpen: _open,
                    onSave: _save,
                  ),
                  if (reads?.guidelineUpdates.isNotEmpty ?? false)
                    _Section(
                      title: 'Guideline updates',
                      items: reads!.guidelineUpdates,
                      onOpen: _open,
                      onSave: _save,
                      showVerify: true,
                    ),
                  if (reads?.isEmpty ?? true)
                    Text(
                      'No curated or retrieved reads for this topic yet. '
                      'Admin can approve curated high-yield items; PubMed '
                      'sections appear when retrieval succeeds.',
                      style: AppTypography.regular(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.onOpen,
    required this.onSave,
    this.showVerify = false,
  });

  final String title;
  final List<TeachingReadItem> items;
  final void Function(TeachingReadItem) onOpen;
  final void Function(TeachingReadItem) onSave;
  final bool showVerify;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.semiBold(
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (TeachingReadItem item) => Container(
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
                  if (item.label.isNotEmpty)
                    Text(
                      item.label,
                      style: AppTypography.semiBold(
                        fontSize: 11,
                        color: item.highYield
                            ? colors.aiAccent
                            : colors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: AppTypography.semiBold(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (item.journal.isNotEmpty || item.date.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (item.organization.isNotEmpty) item.organization,
                        if (item.journal.isNotEmpty) item.journal,
                        if (item.date.isNotEmpty) item.date,
                      ].join(' · '),
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
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
                  if (showVerify || item.verify.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      item.verify.isNotEmpty
                          ? item.verify
                          : 'Verify against the source',
                      style: AppTypography.semiBold(
                        fontSize: 12,
                        color: colors.warning,
                      ),
                    ),
                  ],
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => onOpen(item),
                        child: Text(
                          item.pmid.isEmpty ? 'Open' : 'PMID ${item.pmid}',
                        ),
                      ),
                      if (item.canSaveToReadingList)
                        TextButton(
                          onPressed: () => onSave(item),
                          child: const Text('Save'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
