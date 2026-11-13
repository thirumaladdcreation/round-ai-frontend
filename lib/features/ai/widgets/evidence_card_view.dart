import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/core/utils/external_link.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';

/// One retrieved study. Nothing here comes from model memory.
class EvidenceCardView extends StatelessWidget {
  const EvidenceCardView({
    required this.card,
    this.onOpen = openExternally,
    super.key,
  });

  final EvidenceCard card;

  /// Opens a link outside the app. Tests pass their own.
  final Future<bool> Function(Uri uri) onOpen;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Uri? pubmed = card.pubmedUri;
    final EvidenceCard c = card;
    final String facts = <String>[
      if (c.studyType.isNotEmpty) c.studyType,
      if (c.publicationDate != null) DateFormatter.date(c.publicationDate!),
      if (c.journal.isNotEmpty) c.journal,
    ].join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            c.title.isEmpty ? 'Untitled study' : c.title,
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          if (facts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              facts,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.chipIdle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              c.accessLevel,
              style: AppTypography.medium(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
          ),
          if (c.population != null) _line(colors, 'Population', c.population!),
          if (c.outcomeSummary != null)
            _line(colors, 'Outcome', c.outcomeSummary!),
          if (c.limitations != null)
            _line(colors, 'Limitations', c.limitations!),
          const SizedBox(height: 8),
          Text(
            'How this applies to your patient',
            style: AppTypography.medium(
              fontSize: 12,
              color: colors.textPrimary,
            ),
          ),
          _bucket(colors, 'Resembles', c.applicability.resembles),
          _bucket(colors, 'Differs', c.applicability.differs),
          _bucket(colors, 'Unknown', c.applicability.unknown),
          if (pubmed != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onOpen(pubmed),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('PMID ${c.pmid}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        style: AppTypography.regular(
          fontSize: 12,
          height: 1.35,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  /// A bucket with nothing in it still shows, so a gap is not read as a match.
  Widget _bucket(AppColors colors, String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${items.isEmpty ? 'Not entered' : items.join('; ')}',
        style: AppTypography.regular(
          fontSize: 12,
          height: 1.35,
          color: items.isEmpty ? colors.textMuted : colors.textPrimary,
        ),
      ),
    );
  }
}

/// How the search was run, shown under the results.
class EvidenceRetrievalView extends StatelessWidget {
  const EvidenceRetrievalView({required this.retrieval, super.key});

  final EvidenceRetrieval retrieval;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final EvidenceRetrieval r = retrieval;
    final List<String> lines = <String>[
      if (r.searchedAt != null) 'Searched ${DateFormatter.date(r.searchedAt!)}',
      if (r.sources.isNotEmpty) 'Sources: ${r.sources.join(', ')}',
      if (r.filters.isNotEmpty) 'Filters: ${r.filters.join(', ')}',
      'Retracted papers excluded: ${r.excludedRetracted}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        lines.join('\n'),
        style: AppTypography.regular(
          fontSize: 11,
          height: 1.4,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

const String noEvidenceMessage =
    'No relevant recent studies found in the searched sources.';
