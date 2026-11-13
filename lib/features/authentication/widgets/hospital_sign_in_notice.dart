import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

Future<void> showHospitalSignInNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const HospitalSignInNotice(),
  );
}

/// Explains that hospital SSO is not connected. No account is contacted.
class HospitalSignInNotice extends StatelessWidget {
  const HospitalSignInNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'Hospital sign-in',
        style: AppTypography.headingSemiBold(color: palette.textPrimary),
      ),
      content: Text(
        'Microsoft sign-in is not connected in this demo. '
        'No hospital account is contacted. Use email and password '
        'to open the synthetic workspace.',
        style: AppTypography.bodyMedium(color: palette.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: AppTypography.semiBold(color: palette.primary, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
