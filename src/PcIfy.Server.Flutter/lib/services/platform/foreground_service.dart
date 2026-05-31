abstract class ForegroundService {
  Future<void> start(int port);
  Future<void> stop();
  bool get isRunning;
}
