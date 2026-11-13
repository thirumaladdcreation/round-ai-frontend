import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_log_interceptor.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/shared/widgets/demo_content_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppFeatures.forceAll = null);

  group('hidden features', () {
    test('considerations stay off even with forceAll; chat is on for H1', () {
      AppFeatures.forceAll = true;
      expect(AppFeatures.chat, isTrue);
      expect(AppFeatures.considerations, isFalse);
    });

    test('shell includes learn and scribe; chat is drawer-only', () {
      AppFeatures.forceAll = true;
      expect(ShellTabs.visible.contains(ShellTab.learn), isTrue);
      expect(ShellTabs.visible.contains(ShellTab.scribe), isTrue);
      expect(ShellTabs.visible.contains(ShellTab.chat), isFalse);
    });

    test('routes and endpoints expose chat channels', () {
      expect(AppRoutes.chat, '/chat');
      expect(AppRoutes.chatChannelPath('x'), '/chat/x');
      expect(ApiEndpoints.channels, '/channels');
      expect(ApiEndpoints.chatStream, '/stream');
      expect(ApiEndpoints.teachingPlan, '/teaching/plan');
      expect(AppRoutes.learning, '/learning');
    });
  });

  group('live feature flags', () {
    test('scribe/round/teaching surfaces are on in the real build', () {
      AppFeatures.forceAll = null;
      expect(AppFeatures.rounds, isTrue);
      expect(AppFeatures.learning, isTrue);
      expect(AppFeatures.presentation, isTrue);
      expect(AppFeatures.notes, isTrue);
      expect(AppFeatures.teach, isTrue);
    });
  });

  group('privacy / media', () {
    test('API logger never prints body values', () {
      expect(
        ApiLogInterceptor.describe(<String, String>{
          'display_name': 'Secret Patient',
          'note': 'PHI text',
        }),
        'object(display_name, note)',
      );
      expect(
        ApiLogInterceptor.describe('typed clinical text'),
        'text(19 chars)',
      );
    });

    test('temp media is deleted after success and after throw', () async {
      final Directory dir = await Directory.systemTemp.createTemp('g6_media_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final File file = File('${dir.path}/clip.bin');
      await file.writeAsBytes(const <int>[1, 2, 3]);
      final TempMedia media = TempMedia(
        file: file,
        mimeType: 'application/octet-stream',
        kind: MediaKind.audio,
      );
      await withTempMediaCleanup(media, (TempMedia m) async {
        expect(await m.file.exists(), isTrue);
        return 1;
      });
      expect(await file.exists(), isFalse);

      final File file2 = File('${dir.path}/clip2.bin');
      await file2.writeAsBytes(const <int>[4, 5]);
      final TempMedia media2 = TempMedia(
        file: file2,
        mimeType: 'application/octet-stream',
        kind: MediaKind.image,
      );
      await expectLater(
        withTempMediaCleanup(media2, (TempMedia m) async {
          throw StateError('upload failed');
        }),
        throwsStateError,
      );
      expect(await file2.exists(), isFalse);
    });

    test('iOS permission strings warn against identifiers', () {
      final String plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSCameraUsageDescription'));
      expect(plist, contains('NSMicrophoneUsageDescription'));
      expect(plist, contains('NSPhotoLibraryUsageDescription'));
      expect(plist, contains('Do not photograph names, MRNs or dates of birth'));
      expect(plist, contains('Follow your hospital recording policy'));
      expect(plist, contains('Do not say names, MRNs or dates of birth'));
      expect(plist, contains('Do not choose photos that show names, MRNs'));
    });

    test('Android declares camera and mic permissions', () {
      final String manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
      expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    });
  });

  group('docs', () {
    test('README has Scribe / Round / Teaching section', () {
      final String readme = File('README.md').readAsStringSync();
      expect(readme, contains('## Scribe / Round / Teaching'));
      expect(readme, contains('### Scribe'));
      expect(readme, contains('### Round'));
      expect(readme, contains('### Teaching'));
      expect(readme, contains('Team chat'));
      expect(readme, contains('withTempMediaCleanup'));
      expect(readme.toLowerCase(), contains('no patient names'));
    });
  });

  group('demo banner', () {
    testWidgets('forceShow marks demo pockets', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DemoContentBanner(forceShow: true)),
        ),
      );
      expect(find.text(DemoContentBanner.message), findsOneWidget);
    });
  });
}
