import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../providers/services_providers.dart';
import '../../providers/theme_providers.dart';
import '../../services/theme_service.dart';

// ── Client onboarding wizard ───────────────────────────────────────────────────
//
// Four steps:
//   1. Welcome — what pc-ify offers
//   2. Get server — how to get the server app from GitHub
//   3. Personalize — accent colour, theme, grid density
//   4. All set — prompt to connect to server

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _page = 0;
  static const int _totalPages = 4;

  late Color _selectedColor;
  late ThemeMode _selectedMode;
  late GridDensity _selectedDensity;
  late AccentMode _selectedAccentMode;

  @override
  void initState() {
    super.initState();
    final themeState = ref.read(themeNotifierProvider);
    _selectedColor = themeState.accentColor;
    _selectedMode = themeState.mode;
    _selectedAccentMode = themeState.accentMode;
    final prefs = ref.read(sharedPrefsProvider);
    _selectedDensity =
        GridDensityHelper.fromString(prefs.getString('grid_density') ?? 'normal');
  }

  Future<void> _goNext() async {
    // Apply theme & density immediately when the user taps Next on the
    // personalize page so the change is visible on the next step.
    if (_page == 2) {
      await ref.read(themeNotifierProvider.notifier).apply(
            _selectedMode,
            accentColor: _selectedAccentMode == AccentMode.preset
                ? _selectedColor
                : null,
            accentMode: _selectedAccentMode,
          );
      await ref
          .read(sharedPrefsProvider)
          .setString('grid_density', _selectedDensity.name);
    }
    if (_page < _totalPages - 1 && mounted) setState(() => _page++);
  }

  void _goPrev() {
    if (_page > 0) setState(() => _page--);
  }

  Future<void> _finish() async {
    // Theme & density were applied on the personalize → all-set transition;
    // just mark onboarding complete and navigate.
    try {
      await ref
          .read(sharedPrefsProvider)
          .setBool('client_onboarding_completed', true);
      if (mounted) context.go('/setup');
    } catch (_) {
      // SharedPreferences failure is unlikely; stay on page — _AllSetPageState
      // catch block will re-enable the button.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _goPrev();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: _page > 0,
          leading: _page > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goPrev,
                )
              : null,
          title: _page < _totalPages - 1
              ? Text(
                  'Step ${_page + 1} of $_totalPages',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_page + 1) / _totalPages),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
              ),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(_page),
            child: switch (_page) {
              0 => _WelcomePage(onNext: _goNext),
              1 => _GetServerPage(onNext: _goNext),
              2 => _PersonalizePage(
                  selectedColor: _selectedColor,
                  selectedMode: _selectedMode,
                  selectedDensity: _selectedDensity,
                  selectedAccentMode: _selectedAccentMode,
                  onColorChanged: (c) => setState(() {
                    _selectedColor = c;
                    _selectedAccentMode = AccentMode.preset;
                  }),
                  onSystemAccentSelected: () =>
                      setState(() => _selectedAccentMode = AccentMode.system),
                  onModeChanged: (m) => setState(() => _selectedMode = m),
                  onDensityChanged: (d) => setState(() => _selectedDensity = d),
                  onNext: _goNext,
                ),
              _ => _AllSetPage(onFinish: _finish),
            },
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Welcome ────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(Icons.computer, size: 80, color: cs.primary),
            const SizedBox(height: 28),
            Text(
              'Welcome to pc-ify',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Browse and stream your media from any PC or Android server '
              'on your home network.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            const _FeatureRow(
              icon: Icons.video_library_outlined,
              label: 'Stream videos and music',
            ),
            const SizedBox(height: 14),
            const _FeatureRow(
              icon: Icons.photo_library_outlined,
              label: 'Browse photos and files',
            ),
            const SizedBox(height: 14),
            const _FeatureRow(
              icon: Icons.wifi_outlined,
              label: 'Runs entirely on your local network',
            ),
            const SizedBox(height: 14),
            const _FeatureRow(
              icon: Icons.lock_outline,
              label: 'Secure with JWT authentication',
            ),
            const Spacer(),
            FilledButton(
              onPressed: onNext,
              child: const Text('Get started'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// ── Step 2: Get the server app ─────────────────────────────────────────────────

class _GetServerPage extends StatelessWidget {
  const _GetServerPage({required this.onNext});
  final VoidCallback onNext;

  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/yusairiyap/pc-ify');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(Icons.dns_outlined, size: 80, color: cs.primary),
            const SizedBox(height: 28),
            Text(
              'Get the server app',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You need the pc-ify server running on a PC or another Android device '
              'on the same network as your phone.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const _NumberedStep(
              n: 1,
              label: 'Download the pc-ify server app from GitHub',
            ),
            const SizedBox(height: 14),
            const _NumberedStep(
              n: 2,
              label: 'Install and run it on your PC or Android device',
            ),
            const SizedBox(height: 14),
            const _NumberedStep(
              n: 3,
              label: "Add your media folders in the server's settings",
            ),
            const SizedBox(height: 14),
            const _NumberedStep(
              n: 4,
              label: 'Note the IP address shown in the server app',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openGitHub,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open GitHub — yusairiyap/pc-ify'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: onNext,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.n, required this.label});
  final int n;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$n',
            style: TextStyle(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Personalize ────────────────────────────────────────────────────────

class _PersonalizePage extends StatefulWidget {
  const _PersonalizePage({
    required this.selectedColor,
    required this.selectedMode,
    required this.selectedDensity,
    required this.selectedAccentMode,
    required this.onColorChanged,
    required this.onSystemAccentSelected,
    required this.onModeChanged,
    required this.onDensityChanged,
    required this.onNext,
  });

  final Color selectedColor;
  final ThemeMode selectedMode;
  final GridDensity selectedDensity;
  final AccentMode selectedAccentMode;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onSystemAccentSelected;
  final ValueChanged<ThemeMode> onModeChanged;
  final ValueChanged<GridDensity> onDensityChanged;
  final Future<void> Function() onNext;

  @override
  State<_PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends State<_PersonalizePage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.palette_outlined, size: 80, color: cs.primary),
            const SizedBox(height: 28),
            Text(
              'Make it yours',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Customize the look and feel. You can change these any time in Settings.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            Text('Accent Color',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _saving ? null : widget.onSystemAccentSelected,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          widget.selectedAccentMode == AccentMode.system
                              ? Icons.check
                              : Icons.auto_awesome,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  ...ThemeService.presetColors.map((color) {
                    final selected =
                        widget.selectedAccentMode == AccentMode.preset &&
                            widget.selectedColor == color;
                    return GestureDetector(
                      onTap:
                          _saving ? null : () => widget.onColorChanged(color),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 22,
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Theme', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButton<ThemeMode>(
              value: widget.selectedMode,
              isExpanded: true,
              onChanged: _saving ? null : (v) => widget.onModeChanged(v!),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System default')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
            const SizedBox(height: 24),
            Text('Grid Density',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButton<GridDensity>(
              value: widget.selectedDensity,
              isExpanded: true,
              onChanged: _saving ? null : (v) => widget.onDensityChanged(v!),
              items: GridDensity.values
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(GridDensityHelper.label(d)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 36),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onNext();
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: All set ────────────────────────────────────────────────────────────

class _AllSetPage extends StatefulWidget {
  const _AllSetPage({required this.onFinish});
  final Future<void> Function() onFinish;

  @override
  State<_AllSetPage> createState() => _AllSetPageState();
}

class _AllSetPageState extends State<_AllSetPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Center(child: _AnimatedCheckmark()),
            const SizedBox(height: 36),
            Text(
              "You're all set!",
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Enter your server's IP address and port to start browsing.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        await widget.onFinish();
                      } catch (_) {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect to server'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated checkmark (same design as server wizard) ─────────────────────────

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark();

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final circleScale = CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
        ).value;
        final checkProgress = CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.38, 0.88, curve: Curves.easeInOut),
        ).value;
        final pulse = Tween<double>(begin: 1.0, end: 1.06)
            .animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.88, 1.0, curve: Curves.easeInOut),
              ),
            )
            .value;
        return Transform.scale(
          scale: circleScale * pulse,
          child: SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _CheckPainter(
                progress: checkProgress,
                circleColor: cs.primaryContainer,
                ringColor: cs.primary.withValues(alpha: 0.35),
                checkColor: cs.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color circleColor;
  final Color ringColor;
  final Color checkColor;

  const _CheckPainter({
    required this.progress,
    required this.circleColor,
    required this.ringColor,
    required this.checkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.drawCircle(c, r, Paint()..color = circleColor);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    if (progress <= 0) return;

    final cr = r * 0.54;
    final p1 = Offset(c.dx - cr * 0.52, c.dy + cr * 0.06);
    final p2 = Offset(c.dx - cr * 0.04, c.dy + cr * 0.54);
    final p3 = Offset(c.dx + cr * 0.64, c.dy - cr * 0.44);

    final seg1 = (p2 - p1).distance;
    final seg2 = (p3 - p2).distance;
    final drawn = progress * (seg1 + seg2);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - seg1) / seg2;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      progress != old.progress ||
      circleColor != old.circleColor ||
      checkColor != old.checkColor;
}
