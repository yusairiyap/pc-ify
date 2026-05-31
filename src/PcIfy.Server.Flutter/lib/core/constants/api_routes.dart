abstract final class ApiRoutes {
  static const authLogin = '/api/auth/login';
  static const systemHealth = '/api/system/health';
  static const systemInfo = '/api/system/info';
  static const filesRoots = '/api/files/roots';
  static const filesList = '/api/files/list';
  static const filesStream = '/api/files/stream';
  static const filesDownload = '/api/files/download';
  static const thumbnails = '/api/thumbnails';
  static const tokenQueryParam = 'token';

  static const streamingPrefixes = [
    filesStream,
    filesDownload,
    thumbnails,
  ];
}
