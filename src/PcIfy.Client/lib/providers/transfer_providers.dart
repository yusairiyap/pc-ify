import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/transfer_task.dart';

class TransferState {
  const TransferState({
    this.tasks = const [],
    this.panelVisible = false,
    this.isMinimized = false,
  });

  final List<TransferTask> tasks;
  final bool panelVisible;
  final bool isMinimized;

  bool get hasActive => tasks.any((t) => t.isActive);
  bool get hasAny => tasks.isNotEmpty;

  TransferState copyWith({
    List<TransferTask>? tasks,
    bool? panelVisible,
    bool? isMinimized,
  }) =>
      TransferState(
        tasks: tasks ?? this.tasks,
        panelVisible: panelVisible ?? this.panelVisible,
        isMinimized: isMinimized ?? this.isMinimized,
      );
}

class TransferManagerNotifier extends StateNotifier<TransferState> {
  TransferManagerNotifier() : super(const TransferState());

  final _cancelTokens = <String, CancelToken>{};
  int _idCounter = 0;

  String _newId() => 'transfer_${++_idCounter}';

  (String, CancelToken) addTransfer(String name, TransferType type) {
    final id = _newId();
    final ct = CancelToken();
    _cancelTokens[id] = ct;
    state = state.copyWith(
      tasks: [...state.tasks, TransferTask(id: id, name: name, type: type)],
      panelVisible: true,
      isMinimized: false,
    );
    return (id, ct);
  }

  void updateProgress(String id, int transferred, int total) {
    if (!mounted) return;
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id || !t.isActive) return t;
        return t.withProgress(transferred, total);
      }).toList(),
    );
  }

  void complete(String id) {
    if (!mounted) return;
    final idx = state.tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        return t.copyWith(status: TransferStatus.completed);
      }).toList(),
    );
    _cancelTokens.remove(id);
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != id).toList(),
      );
    });
  }

  void fail(String id, String error) {
    if (!mounted) return;
    final idx = state.tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        return t.copyWith(status: TransferStatus.error, error: error);
      }).toList(),
    );
    _cancelTokens.remove(id);
  }

  void cancel(String id) {
    if (!mounted) return;
    _cancelTokens[id]?.cancel('User cancelled');
    _cancelTokens.remove(id);
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
  }

  void dismiss(String id) {
    if (!mounted) return;
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
  }

  void setMinimized(bool v) => state = state.copyWith(isMinimized: v);
  void showPanel() => state = state.copyWith(panelVisible: true, isMinimized: false);
  void hidePanel() => state = state.copyWith(panelVisible: false);
}

final transferManagerProvider =
    StateNotifierProvider<TransferManagerNotifier, TransferState>(
  (_) => TransferManagerNotifier(),
);
