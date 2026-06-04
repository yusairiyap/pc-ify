enum TransferType { upload, download }
enum TransferStatus { active, completed, error, cancelled }

class TransferTask {
  const TransferTask({
    required this.id,
    required this.name,
    required this.type,
    this.total = 0,
    this.transferred = 0,
    this.bytesPerSec = 0.0,
    this.status = TransferStatus.active,
    this.error,
    this.lastUpdateMs = 0,
  });

  final String id;
  final String name;
  final TransferType type;
  final int total;
  final int transferred;
  final double bytesPerSec;
  final TransferStatus status;
  final String? error;
  final int lastUpdateMs;

  bool get isActive => status == TransferStatus.active;
  double get progress => total > 0 ? transferred / total : 0.0;

  TransferTask withProgress(int newTransferred, int newTotal) {
    final now = DateTime.now().millisecondsSinceEpoch;
    double rate = bytesPerSec;
    if (lastUpdateMs > 0) {
      final elapsedMs = now - lastUpdateMs;
      if (elapsedMs > 50) {
        final delta = newTransferred - transferred;
        if (delta > 0) rate = delta / (elapsedMs / 1000.0);
      }
    }
    return TransferTask(
      id: id,
      name: name,
      type: type,
      total: newTotal,
      transferred: newTransferred,
      bytesPerSec: rate,
      status: status,
      error: error,
      lastUpdateMs: now,
    );
  }

  TransferTask copyWith({TransferStatus? status, String? error}) => TransferTask(
        id: id,
        name: name,
        type: type,
        total: total,
        transferred: transferred,
        bytesPerSec: bytesPerSec,
        status: status ?? this.status,
        error: error ?? this.error,
        lastUpdateMs: lastUpdateMs,
      );
}
