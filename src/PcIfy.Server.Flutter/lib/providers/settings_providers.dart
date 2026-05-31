import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../core/models/app_settings.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final svc = ref.watch(settingsServiceProvider);
  return SettingsNotifier(svc);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(_service.settings);

  Future<void> update(AppSettings settings) async {
    await _service.update(settings);
    state = settings;
  }
}
