import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

/// Private AI draft for the requester. Never posts to the channel.
class ChatSummaryDraftScreen extends StatelessWidget {
  const ChatSummaryDraftScreen({
    required this.draft,
    this.channelTitle,
    super.key,
  });

  final ChatSummaryDraft draft;
  final String? channelTitle;

  String get _copyText {
    final StringBuffer buf = StringBuffer();
    buf.writeln('AI draft · review required');
    if (channelTitle != null && channelTitle!.trim().isNotEmpty) {
      buf.writeln(channelTitle);
    }
    buf.writeln();
    for (final ChatSummaryBullet b in draft.bullets) {
      buf.writeln('• ${b.text}');
    }
    if (draft.openQuestions.isNotEmpty) {
      buf.writeln();
      buf.writeln('Open questions');
      for (final String q in draft.openQuestions) {
        buf.writeln('• $q');
      }
    }
    if (draft.missingInformation.isNotEmpty) {
      buf.writeln();
      buf.writeln('Missing information');
      for (final String m in draft.missingInformation) {
        buf.writeln('• $m');
      }
    }
    buf.writeln();
    buf.writeln(draft.disclaimer);
    return buf.toString().trim();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _copyText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft copied. Review before sharing.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Thread summary',
          style: AppTypography.semiBold(
            fontSize: 17,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'AI draft · review required',
              style: AppTypography.semiBold(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            draft.disclaimer,
            style: AppTypography.regular(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This draft is only for you. It was not posted to the channel.',
            style: AppTypography.regular(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          if (draft.bullets.isEmpty)
            Text(
              'No summary bullets were returned.',
              style: AppTypography.regular(
                fontSize: 14,
                color: colors.textMuted,
              ),
            )
          else
            for (final ChatSummaryBullet b in draft.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '•  ',
                      style: AppTypography.regular(
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b.text,
                        style: AppTypography.regular(
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (draft.openQuestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Open questions',
              style: AppTypography.semiBold(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final String q in draft.openQuestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $q',
                  style: AppTypography.regular(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
              ),
          ],
          if (draft.missingInformation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Missing information',
              style: AppTypography.semiBold(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final String m in draft.missingInformation)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $m',
                  style: AppTypography.regular(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Copy draft',
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }
}
