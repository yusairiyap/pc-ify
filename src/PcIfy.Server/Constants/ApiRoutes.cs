namespace PcIfy.Server.Constants;

public static class ApiRoutes
{
    public const string AuthLogin = "/api/auth/login";

    public const string SystemHealth = "/api/system/health";
    public const string SystemInfo = "/api/system/info";

    public const string FilesRoots = "/api/files/roots";
    public const string FilesList = "/api/files/list";
    public const string FilesStream = "/api/files/stream";
    public const string FilesDownload = "/api/files/download";
    public const string FilesUpload = "/api/files/upload";
    public const string FilesDelete = "/api/files/delete";
    public const string FilesCopy = "/api/files/copy";
    public const string FilesMove = "/api/files/move";

    public const string Thumbnails = "/api/thumbnails";

    public const string TokenQueryParam = "token";

    public const string SystemControlStatus        = "/api/system/control/status";
    public const string SystemControlVolume        = "/api/system/control/volume";
    public const string SystemControlMute          = "/api/system/control/mute";
    public const string SystemControlLock          = "/api/system/control/lock";
    public const string SystemControlWake          = "/api/system/control/wake";
}
