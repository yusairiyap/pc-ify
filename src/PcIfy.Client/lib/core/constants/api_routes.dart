abstract final class ApiRoutes {
  static const login = '/api/auth/login';
  static const health = '/api/system/health';
  static const info = '/api/system/info';
  static const roots = '/api/files/roots';
  static const list = '/api/files/list';
  static const stream = '/api/files/stream';
  static const download = '/api/files/download';
  static const upload = '/api/files/upload';
  static const filesDelete = '/api/files/delete';
  static const filesCopy = '/api/files/copy';
  static const filesMove = '/api/files/move';
  static const thumbnails = '/api/thumbnails';
  static const tokenParam = 'token';

  static const controlStatus        = '/api/system/control/status';
  static const controlVolume        = '/api/system/control/volume';
  static const controlMute          = '/api/system/control/mute';
  static const controlLock          = '/api/system/control/lock';
  static const controlWake          = '/api/system/control/wake';
}
