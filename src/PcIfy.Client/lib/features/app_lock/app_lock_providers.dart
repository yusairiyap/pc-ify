import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../providers/http_providers.dart';
import '../../providers/services_providers.dart';
import '../../services/app_lock_service.dart';

export '../../services/app_lock_service.dart' show AppLockType, AppLockService;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class LockState {
  const LockState({
    required this.lockType,
    required this.isLocked,
    this.failedAttempts = 0,
  });

  final AppLockType lockType;
  final bool isLocked;
  final int failedAttempts;

  LockState copyWith({
    AppLockType? lockType,
    bool? isLocked,
    int? failedAttempts,
  }) =>
      LockState(
        lockType: lockType ?? this.lockType,
        isLocked: isLocked ?? this.isLocked,
        failedAttempts: failedAttempts ?? this.failedAttempts,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LockNotifier extends Notifier<LockState> {
  @override
  LockState build() {
    final service = ref.watch(appLockServiceProvider);

    // When the server session expires, dismiss the lock so it doesn't stack
    // on top of the /setup screen.
    ref.listen(sessionExpiredProvider, (_, expired) {
      if (expired) state = state.copyWith(isLocked: false);
    });

    // Start locked immediately if a lock type is configured, so the home
    // screen is never visible before authentication. _armOnColdStart() in
    // app.dart will call unlock() if there is no valid session (i.e. the user
    // will be redirected to /setup anyway).
    final type = service.getLockType();
    return LockState(lockType: type, isLocked: type != AppLockType.none);
  }

  void lock() => state = state.copyWith(isLocked: true);

  void unlock() => state = state.copyWith(isLocked: false, failedAttempts: 0);

  void recordFailedAttempt() =>
      state = state.copyWith(failedAttempts: state.failedAttempts + 1);

  void refreshType() {
    final service = ref.read(appLockServiceProvider);
    state = state.copyWith(lockType: service.getLockType());
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService(
    ref.watch(sharedPrefsProvider),
    const FlutterSecureStorage(),
  );
});

final lockNotifierProvider =
    NotifierProvider<LockNotifier, LockState>(LockNotifier.new);
