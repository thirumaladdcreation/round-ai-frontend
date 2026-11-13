import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({AppStorage storage, MemoryTokenStore store})> _storage() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final MemoryTokenStore store = MemoryTokenStore();
  final AppStorage storage = AppStorage(
    await SharedPreferences.getInstance(),
    session: SessionStore(store),
  );
  return (storage: storage, store: store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStore', () {
    test('Remember me off keeps the token in memory only', () async {
      final MemoryTokenStore disk = MemoryTokenStore();
      final SessionStore session = SessionStore(disk);
      await session.save('tok', persist: false);
      expect(session.hasToken, isTrue);
      expect(await disk.read(), isNull);

      final SessionStore relaunched = SessionStore(disk);
      await relaunched.restore();
      expect(relaunched.hasToken, isFalse);
    });

    test('Remember me on survives a relaunch, clear removes it', () async {
      final MemoryTokenStore disk = MemoryTokenStore();
      await SessionStore(disk).save('tok', persist: true);

      final SessionStore relaunched = SessionStore(disk);
      await relaunched.restore();
      expect(relaunched.token, 'tok');

      await relaunched.clear();
      expect(relaunched.hasToken, isFalse);
      expect(await disk.read(), isNull);
    });

    test('the token never goes into shared_preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppStorage storage = AppStorage(
        prefs,
        session: SessionStore(MemoryTokenStore()),
      );
      await storage.session.save('secret-token', persist: true);
      expect(
        prefs.getKeys().map((String k) => prefs.get(k).toString()),
        isNot(contains('secret-token')),
      );
    });

    test('an old demo token in preferences is purged', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_token': 'local-demo-session',
      });
      final AppStorage storage = AppStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.purgeLegacyToken();
      expect(storage.readString('auth_token'), isNull);
      expect(storage.hasAuthToken, isFalse);
    });

    test('signing out clears the token and the saved team', () async {
      final s = await _storage();
      await s.storage.session.save('tok', persist: true);
      await s.storage.saveSelectedTeam('t1');
      await s.storage.clearAuthSession();
      expect(s.storage.hasAuthToken, isFalse);
      expect(s.storage.hasSelectedTeam, isFalse);
      expect(await s.store.read(), isNull);
    });
  });
}
