import 'package:url_launcher/url_launcher.dart';

/// Opens a link in the browser, outside the app. Returns false if it could
/// not be opened. Nothing about the patient is part of the link.
Future<bool> openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
