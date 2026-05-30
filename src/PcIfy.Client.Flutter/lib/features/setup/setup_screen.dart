import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/services_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5000');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _showLogin = false;
  bool _isBusy = false;
  String _serverName = '';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final baseUrl = ref.read(connectionServiceProvider).baseUrl;
    if (baseUrl.isEmpty) return;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return;
    _hostCtrl.text = uri.host;
    _portCtrl.text = uri.port.toString();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 5000;
    if (host.isEmpty) return;

    setState(() {
      _isBusy = true;
      _statusMessage = 'Connecting…';
      _showLogin = false;
    });

    final conn = ref.read(connectionServiceProvider);
    await conn.setBaseUrl('http://$host:$port');

    final api = ref.read(apiServiceProvider);
    final ok = await api.ping();
    if (!ok) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Cannot reach server at $host:$port';
      });
      return;
    }

    final info = await api.getServerInfo();
    setState(() {
      _isBusy = false;
      _serverName = info?.serverName ?? 'Server';
      _statusMessage = 'Connected to ${info?.serverName ?? host}';
      _showLogin = true;
    });
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) return;

    setState(() {
      _isBusy = true;
      _statusMessage = 'Signing in…';
    });

    final api = ref.read(apiServiceProvider);
    final result = await api.login(user, pass);

    if (result == null) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Invalid username or password';
      });
      return;
    }

    await ref.read(authTokenServiceProvider).saveToken(result.token);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.surface, cs.surfaceContainerLowest],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.computer, size: 64, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      'pc-ify',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect to your server',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Server Address',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: cs.primary)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _hostCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Host',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _portCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Port',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _testConnection(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _isBusy ? null : _testConnection,
                            child: _isBusy && !_showLogin
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Test Connection'),
                          ),
                        ],
                      ),
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showLogin ? cs.primary : cs.error,
                        ),
                      ),
                    ],
                    if (_showLogin) ...[
                      const SizedBox(height: 16),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Login to $_serverName',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: cs.primary)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _userCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _isBusy ? null : _login,
                              child: _isBusy && _showLogin
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Sign In'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
