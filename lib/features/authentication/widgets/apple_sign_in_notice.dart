import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

Future<void> showAppleSignInNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const AppleSignInNotice(),
  );
}

/// Apple sign-in is not connected, so this does not contact an Apple ID.
class AppleSignInNotice extends StatelessWidget {
  const AppleSignInNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = dark ? RoundsBrand.slate : RoundsBrand.white;
    final Color text = dark ? RoundsBrand.white : RoundsBrand.charcoal;
    final Color body = dark ? RoundsBrand.pale : RoundsBrand.slate;
    return AlertDialog(
      backgroundColor: surface,
      title: Text(
        'Apple sign-in',
        style: AppTypography.inter(
          AppTypography.semiBold(color: text, fontSize: 18),
        ),
      ),
      content: Text(
        'Apple sign-in is not connected. No Apple ID is contacted. '
        'Use email and password when your hospital account is available.',
        style: AppTypography.inter(
          AppTypography.regular(color: body, fontSize: 14),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: AppTypography.inter(
              AppTypography.semiBold(color: RoundsBrand.aqua, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
