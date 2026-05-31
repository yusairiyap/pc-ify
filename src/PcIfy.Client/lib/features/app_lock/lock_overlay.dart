import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app_lock_providers.dart';
import 'pin_keypad.dart';

class LockOverlay extends ConsumerStatefulWidget {
  const LockOverlay({super.key, required this.lockType});

  final AppLockType lockType;

  @override
  ConsumerState<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends ConsumerState<LockOverlay> {
  @override
  void initState() {
    super.initState();
    if (widget.lockType == AppLockType.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock pc-ify',
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) {
        ref.read(lockNotifierProvider.notifier).unlock();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: switch (widget.lockType) {
              AppLockType.biometric => _BiometricBody(onRetry: _tryBiometric),
              AppLockType.pin => const _PinBody(),
              AppLockType.password => const _PasswordBody(),
              AppLockType.none => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Biometric body
// ---------------------------------------------------------------------------

class _BiometricBody extends StatelessWidget {
  const _BiometricBody({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fingerprint,
            size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('Unlock pc-ify',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Authenticate to continue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PIN body
// ---------------------------------------------------------------------------

class _PinBody extends ConsumerStatefulWidget {
  const _PinBody();

  @override
  ConsumerState<_PinBody> createState() => _PinBodyState();
}

class _PinBodyState extends ConsumerState<_PinBody>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;
  String _entered = '';
  bool _error = false;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += d;
      _error = false;
    });
    if (_entered.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    final service = ref.read(appLockServiceProvider);
    final ok = await service.verifyCredential(_entered);
    if (!mounted) return;
    if (ok) {
      ref.read(lockNotifierProvider.notifier).unlock();
    } else {
      ref.read(lockNotifierProvider.notifier).recordFailedAttempt();
      setState(() {
        _entered = '';
        _error = true;
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: cs.primary),
            const SizedBox(height: 24),
            Text('Enter PIN', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) {
                final offset = _error
                    ? Offset(_shakeAnim.value * 8 * ((_shakeCtrl.value * 8).toInt().isEven ? 1 : -1), 0)
                    : Offset.zero;
                return Transform.translate(offset: offset, child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error
                          ? cs.error
                          : filled
                              ? cs.primary
                              : cs.outlineVariant,
                    ),
                  );
                }),
              ),
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              Text('Incorrect PIN',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.error)),
            ],
            const SizedBox(height: 32),
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Password body
// ---------------------------------------------------------------------------

class _PasswordBody extends ConsumerStatefulWidget {
  const _PasswordBody();

  @override
  ConsumerState<_PasswordBody> createState() => _PasswordBodyState();
}

class _PasswordBodyState extends ConsumerState<_PasswordBody> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _obscure = true;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _ctrl.text.isEmpty) return;
    setState(() => _busy = true);
    final service = ref.read(appLockServiceProvider);
    final ok = await service.verifyCredential(_ctrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(lockNotifierProvider.notifier).unlock();
    } else {
      ref.read(lockNotifierProvider.notifier).recordFailedAttempt();
      setState(() => _error = true);
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 48, color: cs.primary),
        const SizedBox(height: 24),
        Text('Enter Password',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _error ? 'Incorrect password' : null,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) {
            if (_error) setState(() => _error = false);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Unlock'),
          ),
        ),
      ],
    );
  }
}
