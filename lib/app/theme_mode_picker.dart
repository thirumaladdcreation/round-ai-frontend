import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/app/theme_cubit.dart';

/// Light, Dark, and System choice. Reads and writes [ThemeCubit].
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeMode selected = context.watch<ThemeCubit>().state;
    final AppPalette palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Appearance',
          style: AppTypography.sectionHeading(color: palette.textPrimary),
        ),
        const SizedBox(height: 8),
        ThemeModeOption(
          mode: ThemeMode.light,
          label: 'Light',
          icon: Icons.light_mode_outlined,
          selected: selected,
        ),
        ThemeModeOption(
          mode: ThemeMode.dark,
          label: 'Dark',
          icon: Icons.dark_mode_outlined,
          selected: selected,
        ),
        ThemeModeOption(
          mode: ThemeMode.system,
          label: 'Match device',
          icon: Icons.phone_iphone_outlined,
          selected: selected,
        ),
      ],
    );
  }
}

/// One appearance choice. Kept public so the picker stays a small file.
class ThemeModeOption extends StatelessWidget {
  const ThemeModeOption({
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
    super.key,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final ThemeMode selected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool isSelected = selected == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: palette.textPrimary),
      title: Text(
        label,
        style: AppTypography.bodyMedium(color: palette.textPrimary),
      ),
      trailing: Icon(
        isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: isSelected ? palette.primary : palette.textSecondary,
      ),
      onTap: () => context.read<ThemeCubit>().setMode(mode),
    );
  }
}
