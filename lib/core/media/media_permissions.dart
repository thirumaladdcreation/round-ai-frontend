import 'package:permission_handler/permission_handler.dart';

/// When a permission is needed. Reasons match the platform strings in
/// Info.plist / AndroidManifest.
enum MediaPermissionUse { camera, microphone, photos }

/// Result of asking for a permission at the moment of use.
enum MediaPermissionResult { granted, denied, permanentlyDenied }

/// Asks for camera, microphone or photos only when the user taps capture.
class MediaPermissions {
  const MediaPermissions();

  Future<MediaPermissionResult> ensure(MediaPermissionUse use) async {
    final Permission permission = switch (use) {
      MediaPermissionUse.camera => Permission.camera,
      MediaPermissionUse.microphone => Permission.microphone,
      MediaPermissionUse.photos => Permission.photos,
    };
    PermissionStatus status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return MediaPermissionResult.granted;
    }
    status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return MediaPermissionResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MediaPermissionResult.permanentlyDenied;
    }
    return MediaPermissionResult.denied;
  }

  /// Opens the OS settings page so the user can turn a denied permission on.
  Future<bool> openSettings() => openAppSettings();
}
