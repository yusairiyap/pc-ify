import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connection_log_service.dart';
import '../core/models/connection_log_entry.dart';

final connectionLogServiceProvider =
    Provider<ConnectionLogService>((ref) {
  final svc = ConnectionLogService();
  ref.onDispose(svc.dispose);
  return svc;
});

final logEntriesProvider =
    StreamProvider<ConnectionLogEntry>((ref) {
  final svc = ref.watch(connectionLogServiceProvider);
  return svc.stream;
});
