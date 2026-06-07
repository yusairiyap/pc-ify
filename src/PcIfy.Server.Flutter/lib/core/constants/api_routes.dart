abstract final class ApiRoutes {
  static const authLogin = '/api/auth/login';
  static const systemHealth = '/api/system/health';
  static const systemInfo = '/api/system/info';
  static const filesRoots = '/api/files/roots';
  static const filesList = '/api/files/list';
  static const filesStream = '/api/files/stream';
  static const filesDownload = '/api/files/download';
  static const filesUpload = '/api/files/upload';
  static const filesDelete = '/api/files/delete';
  static const filesCopy = '/api/files/copy';
  static const filesMove = '/api/files/move';
  static const thumbnails = '/api/thumbnails';
  static const tokenQueryParam = 'token';

  static const systemControlStatus        = '/api/system/control/status';
  static const systemControlVolume        = '/api/system/control/volume';
  static const systemControlMute          = '/api/system/control/mute';
  static const systemControlLock          = '/api/system/control/lock';
  static const systemControlWake          = '/api/system/control/wake';
  static const systemControlClipboard     = '/api/system/control/clipboard';

  static const systemApps                 = '/api/system/apps';
  static const systemAppsLaunch           = '/api/system/apps/launch';
  static const systemAppsAdd              = '/api/system/apps/add';

  static const filesVideoInfo = '/api/files/video-info';

  static const streamingPrefixes = [
    filesStream,
    filesDownload,
    thumbnails,
  ];
}
