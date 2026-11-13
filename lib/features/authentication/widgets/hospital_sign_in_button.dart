import 'package:flutter/material.dart';
import 'package:round_ai/features/authentication/widgets/hospital_sign_in_notice.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class HospitalSignInButton extends StatelessWidget {
  const HospitalSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Continue with Microsoft',
      variant: AppButtonVariant.outline,
      icon: const HospitalSsoMark(),
      onPressed: () => showHospitalSignInNotice(context),
    );
  }
}

/// Four-square mark for the hospital SSO button. No Microsoft session is opened.
class HospitalSsoMark extends StatelessWidget {
  const HospitalSsoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: <Widget>[
          SsoSquare(Color(0xFFF25022)),
          SsoSquare(Color(0xFF7FBA00)),
          SsoSquare(Color(0xFF00A4EF)),
          SsoSquare(Color(0xFFFFB900)),
        ],
      ),
    );
  }
}

class SsoSquare extends StatelessWidget {
  const SsoSquare(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 7, height: 7, color: color);
  }
}
