import 'dart:async';
import '../core/models/connection_log_entry.dart';

class ConnectionLogService {
  static const _maxEntries = 1000;

  final List<ConnectionLogEntry> _entries = [];
  final _controller = StreamController<ConnectionLogEntry>.broadcast();

  List<ConnectionLogEntry> get entries => List.unmodifiable(_entries);
  Stream<ConnectionLogEntry> get stream => _controller.stream;

  void log(ConnectionLogEntry entry) {
    if (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    _controller.add(entry);
  }

  List<ConnectionLogEntry> getRecent(int count) {
    final start = (_entries.length - count).clamp(0, _entries.length);
    return _entries.sublist(start).reversed.toList();
  }

  void clear() => _entries.clear();

  void dispose() => _controller.close();
}
