import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:greyvetro_budget_tracker/core/auth/app_user.dart';
import 'package:greyvetro_budget_tracker/core/auth/auth_service.dart';
import 'package:greyvetro_budget_tracker/core/pin_lock/pin_store.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/data/budget_repository.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/account.dart';
import 'package:greyvetro_budget_tracker/features/net_worth/models/monthly_entry.dart';
import 'package:greyvetro_budget_tracker/main.dart';

/// Always-signed-in fake so widget tests can reach the app without touching
/// real Firebase Auth.
class _FakeAuthService implements AuthService {
  static const _user = AppUser(uid: 'test-uid');

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_user);

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser> signIn() async => _user;

  @override
  Future<void> signOut() async {}
}

/// Fake secure-storage backend so `PinGate`'s `PinStore.isEnabled()` check
/// resolves instead of hitting an unmocked platform channel — same fake used
/// by `vault_entry_test.dart`.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map.of(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

class _FakeBudgetRepository implements BudgetRepository {
  @override
  Stream<List<Account>> watchAccounts() => Stream.value(const []);

  @override
  Future<void> addAccount(Account account) async {}

  @override
  Future<void> updateAccount(Account account) async {}

  @override
  Future<void> setAccountActive(String accountId, bool active) async {}

  @override
  Stream<List<MonthlyEntry>> watchMonthlyEntries() => Stream.value(const []);

  @override
  Future<MonthlyEntry?> getMonthlyEntry(String entryId) async => null;

  @override
  Future<void> saveMonthlyEntry(MonthlyEntry entry) async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    await PinStore.instance.clear();

    // HomeScreen's launch checks call ReminderScheduler.scheduleMonthEndReminder,
    // which needs the timezone database (normally loaded by main()'s
    // ReminderScheduler.init(), which this test bypasses) and talks to the
    // flutter_local_notifications platform channel — mock both so the
    // launch check resolves instead of throwing.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    // Real plugin registration never runs in a widget test — register the
    // real (channel-based) Android implementation so
    // `resolvePlatformSpecificImplementation` finds a non-null match; its
    // channel calls land on the mock handler set up below.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
  });

  testWidgets('Home screen renders with no data', (tester) async {
    await tester.pumpWidget(
      BudgetTrackerApp(
        authService: _FakeAuthService(),
        repositoryBuilder: (_) => _FakeBudgetRepository(),
        prepare: (_, _) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Net Worth Tracker'), findsOneWidget);
    expect(find.text('Liquidity across all accounts'), findsOneWidget);
    // ₱0.00 renders for the hero net-worth value plus its Assets and
    // Reserved & Liabilities footer figures.
    expect(find.text('₱0.00'), findsNWidgets(3));
    expect(find.text('0 active accounts'), findsOneWidget);
    expect(find.text('0 snapshots recorded'), findsOneWidget);

    // The "Recent snapshots" empty state sits below several chart cards, so
    // scroll the Home screen's list until it's actually built.
    await tester.scrollUntilVisible(find.text('No months tracked yet.'), 300);
    expect(find.text('No months tracked yet.'), findsOneWidget);
  });
}
