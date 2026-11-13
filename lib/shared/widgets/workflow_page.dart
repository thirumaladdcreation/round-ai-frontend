import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

class WorkflowPage extends StatelessWidget {
  const WorkflowPage({
    required this.title,
    required this.children,
    this.status,
    super.key,
  });

  final String title;
  final String? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.textPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.semiBold(
                      fontSize: 18,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (status != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                status!,
                style: AppTypography.semiBold(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.title,
    required this.body,
    this.label,
    this.tint,
    this.border,
    super.key,
  });

  final String title;
  final String body;
  final String? label;
  final Color? tint;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint ?? colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.semiBold(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              label!,
              style: AppTypography.medium(color: colors.primary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.regular(
              color: colors.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
