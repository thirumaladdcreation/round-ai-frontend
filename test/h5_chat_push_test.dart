import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/chat/models/chat_push_payload.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_push_controller.dart';
import 'package:round_ai/features/chat/services/chat_push_permission.dart';
import 'package:round_ai/features/chat/services/chat_push_token_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

Future<AppStorage> _storage() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppStorage(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPushPayload', () {
    test('display copy is generic', () {
      expect(ChatPushPayload.displayTitle, 'New message');
      expect(ChatPushPayload.displayBody, 'Open RoundsAI');
    });

    test('parses opaque channel_id only; ignores body/title', () {
      final ChatPushPayload payload = ChatPushPayload.parse(<Object?, Object?>{
        'title': 'Rosa Martinez · Room 509A',
        'body': 'Creatinine rose overnight',
        'channel_id': 'demo-patient-1',
      });
      expect(payload.channelId, 'demo-patient-1');
      expect(payload.routePath, '/chat/demo-patient-1');
    });

    test('rejects label-like channel values', () {
      expect(
        ChatPushPayload.parse(<Object?, Object?>{
          'channel_id': 'Room 509A',
        }).channelId,
        isNull,
      );
      expect(
        ChatPushPayload.parse(<Object?, Object?>{
          'channel_id': 'nurse@hospital',
        }).channelId,
        isNull,
      );
    });
  });

  group('registerDevice', () {
    test('demo validates platform and token length', () async {
      final DemoChatRepository chat = DemoChatRepository();
      expect(
        await chat.registerDevice(platform: 'android', token: 'short'),
        isA<Err<void>>(),
      );
      expect(
        await chat.registerDevice(platform: 'blackberry', token: 'longenough'),
        isA<Err<void>>(),
      );
      expect(
        await chat.registerDevice(platform: 'ios', token: 'longenough'),
        isA<Ok<void>>(),
      );
    });

    test('impl posts platform + token to /chat/devices', () async {
      Map<String, Object?>? body;
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        expect(o.method, 'POST');
        expect(o.path, '/chat/devices');
        body = Map<String, Object?>.from(o.data as Map);
        return FakeReply(200, <String, Object>{'ok': true});
      });
      final ChatRepositoryImpl repo = ChatRepositoryImpl(
        await _client(adapter),
      );
      final Result<void> result = await repo.registerDevice(
        platform: 'android',
        token: 'fcm-token-abcdefgh',
      );
      expect(result, isA<Ok<void>>());
      expect(body?['platform'], 'android');
      expect(body?['token'], 'fcm-token-abcdefgh');
    });
  });

  group('ChatPushController', () {
    test('opt-in registers after permission; open waits for auth', () async {
      final AppStorage storage = await _storage();
      final List<String> paths = <String>[];
      bool loggedIn = true;
      final FakeChatPushPermission permission = FakeChatPushPermission();
      final ChatPushController push = ChatPushController(
        chat: DemoChatRepository(),
        storage: storage,
        tokenSource: StubChatPushTokenSource(storage: storage),
        permission: permission,
        navigate: paths.add,
        isLoggedIn: () => loggedIn,
        platform: 'android',
      );

      push.refreshOptInVisibility(chatEnabled: true);
      expect(push.optInVisible.value, isTrue);

      final bool registered = await push.acceptOptInAndRegister();
      expect(registered, isTrue);
      expect(push.hasOptedIn, isTrue);
      expect(push.optInVisible.value, isFalse);
      expect(permission.granted, isTrue);

      loggedIn = false;
      push.openFromNotification(
        const ChatPushPayload(channelId: 'demo-general'),
      );
      expect(paths.single, AppRoutes.signIn);
      expect(push.pendingChannelId, 'demo-general');

      loggedIn = true;
      paths.clear();
      push.consumePendingOpen();
      expect(paths.single, AppRoutes.chatChannelPath('demo-general'));
      expect(push.pendingChannelId, isNull);

      push.openFromNotification(
        const ChatPushPayload(channelId: 'demo-patient-1'),
      );
      expect(paths.last, AppRoutes.chatChannelPath('demo-patient-1'));

      await push.clear();
      push.dispose();
    });

    test('dismiss hides opt-in without registering', () async {
      final AppStorage storage = await _storage();
      final ChatPushController push = ChatPushController(
        chat: DemoChatRepository(),
        storage: storage,
        tokenSource: StubChatPushTokenSource(storage: storage),
        permission: FakeChatPushPermission(),
        navigate: (_) {},
        isLoggedIn: () => true,
        platform: 'ios',
      );
      push.refreshOptInVisibility(chatEnabled: true);
      await push.dismissOptIn();
      expect(push.hasDismissedOptIn, isTrue);
      push.refreshOptInVisibility(chatEnabled: true);
      expect(push.optInVisible.value, isFalse);
      push.dispose();
    });
  });

}
