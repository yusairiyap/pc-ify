import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_providers.dart';
import 'pin_keypad.dart';

class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key, this.isChange = false});

  final bool isChange;

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;

  String _first = '';
  String _entered = '';
  bool _confirming = false;
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
    if (_entered.length == _pinLength) _advance();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _advance() async {
    if (!_confirming) {
      setState(() {
        _first = _entered;
        _entered = '';
        _confirming = true;
      });
    } else {
      if (_entered == _first) {
        final service = ref.read(appLockServiceProvider);
        await service.saveCredential(_entered);
        await service.setLockType(AppLockType.pin);
        ref.read(lockNotifierProvider.notifier).refreshType();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _entered = '';
          _first = '';
          _confirming = false;
          _error = true;
        });
        _shakeCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.isChange ? 'Change PIN' : 'Set PIN';
    final subtitle = _confirming ? 'Confirm your PIN' : 'Enter a 4-digit PIN';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(subtitle,
                    style: Theme.of(context).textTheme.titleMedium),
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
                  Text("PINs don't match — try again",
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
        ),
      ),
    );
  }
}
