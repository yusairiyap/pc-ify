using System.Runtime.InteropServices;
using PcIfy.Server.DTOs.System;
using PcIfy.Server.Services.Interfaces;
using Timer = System.Threading.Timer;

namespace PcIfy.Server.Services;

public sealed class WindowsSystemControlService : ISystemControlService, IDisposable
{
    // CPU: pre-warm and cache via a background timer
    private volatile float _cpuCache;
    private readonly System.Diagnostics.PerformanceCounter _cpuCounter;
    private readonly Timer _cpuTimer;

    public WindowsSystemControlService()
    {
        _cpuCounter = new System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total");
        _cpuCounter.NextValue(); // discard first 0 reading
        _cpuTimer = new Timer(_ =>
        {
            try { _cpuCache = _cpuCounter.NextValue(); }
            catch { /* ignore if perf counter unavailable */ }
        }, null, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2));
    }

    public ControlStatusDto GetStatus()
    {
        var battery = GetBattery();
        var volume = GetVolume();
        var cpu = new CpuStatusDto((double)Math.Round(_cpuCache, 1), true);
        var ram = GetRam();
        var screen = new ScreenStatusDto(false, false); // Windows can't query lock state publicly
        return new ControlStatusDto(battery, volume, cpu, ram, screen);
    }

    private static BatteryStatusDto GetBattery()
    {
        try
        {
            var ps = System.Windows.Forms.SystemInformation.PowerStatus;
            var pct = ps.BatteryLifePercent;
            if (pct > 1f) return new BatteryStatusDto(0, false, false); // no battery (desktop)
            return new BatteryStatusDto(
                (int)(pct * 100),
                ps.PowerLineStatus == System.Windows.Forms.PowerLineStatus.Online,
                true);
        }
        catch { return new BatteryStatusDto(0, false, false); }
    }

    // RAM via P/Invoke
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    private static RamStatusDto GetRam()
    {
        try
        {
            var mem = new MEMORYSTATUSEX { dwLength = (uint)Marshal.SizeOf<MEMORYSTATUSEX>() };
            if (!GlobalMemoryStatusEx(ref mem)) return new RamStatusDto(0, 0, false);
            var usedMb = (long)((mem.ullTotalPhys - mem.ullAvailPhys) / (1024 * 1024));
            var totalMb = (long)(mem.ullTotalPhys / (1024 * 1024));
            return new RamStatusDto(usedMb, totalMb, true);
        }
        catch { return new RamStatusDto(0, 0, false); }
    }

    private static VolumeStatusDto GetVolume()
    {
        try
        {
            using var vol = AudioEndpointVolume.GetDefault();
            if (vol == null) return new VolumeStatusDto(50, false, false);
            var level = (int)(vol.GetMasterVolumeLevelScalar() * 100);
            var muted = vol.GetMute();
            return new VolumeStatusDto(level, muted, true);
        }
        catch { return new VolumeStatusDto(50, false, false); }
    }

    public void SetVolume(int level)
    {
        try
        {
            using var vol = AudioEndpointVolume.GetDefault();
            vol?.SetMasterVolumeLevelScalar(Math.Clamp(level, 0, 100) / 100f, Guid.Empty);
        }
        catch { /* ignore */ }
    }

    public void SetMute(bool muted)
    {
        try
        {
            using var vol = AudioEndpointVolume.GetDefault();
            vol?.SetMute(muted, Guid.Empty);
        }
        catch { /* ignore */ }
    }

    // Screen lock
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    public void LockScreen()
    {
        try { LockWorkStation(); } catch { /* ignore */ }
    }

    // Wake: simulate mouse move
    [DllImport("user32.dll")]
    private static extern void mouse_event(uint dwFlags, int dx, int dy, uint cButtons, UIntPtr dwExtraInfo);
    private const uint MOUSEEVENTF_MOVE = 0x0001;

    public void WakeScreen()
    {
        try { mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, UIntPtr.Zero); } catch { /* ignore */ }
    }

    // Notifications: not available without MSIX packaging
    public IReadOnlyList<NotificationItemDto> GetNotifications() => Array.Empty<NotificationItemDto>();
    public void ClearNotifications() { }

    public void Dispose()
    {
        _cpuTimer.Dispose();
        _cpuCounter.Dispose();
    }
}

// Minimal Windows Core Audio COM interop — no NuGet needed
internal sealed class AudioEndpointVolume : IDisposable
{
    private readonly IAudioEndpointVolume _vol;

    private AudioEndpointVolume(IAudioEndpointVolume vol) => _vol = vol;

    public static AudioEndpointVolume? GetDefault()
    {
        try
        {
            var enumeratorType = Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"))!;
            var enumerator = (IMMDeviceEnumerator)Activator.CreateInstance(enumeratorType)!;
            enumerator.GetDefaultAudioEndpoint(0 /*eRender*/, 1 /*eMultimedia*/, out var device);
            device.Activate(typeof(IAudioEndpointVolume).GUID, 0, IntPtr.Zero, out var obj);
            if (obj is IAudioEndpointVolume vol) return new AudioEndpointVolume(vol);
            return null;
        }
        catch { return null; }
    }

    public float GetMasterVolumeLevelScalar()
    {
        _vol.GetMasterVolumeLevelScalar(out var level);
        return level;
    }

    public bool GetMute()
    {
        _vol.GetMute(out var muted);
        return muted;
    }

    public void SetMasterVolumeLevelScalar(float level, Guid eventContext) =>
        _vol.SetMasterVolumeLevelScalar(level, ref eventContext);

    public void SetMute(bool muted, Guid eventContext) =>
        _vol.SetMute(muted, ref eventContext);

    public void Dispose()
    {
        if (_vol is not null) Marshal.ReleaseComObject(_vol);
    }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator
    {
        void EnumAudioEndpoints(int dataFlow, uint stateMask, out object devices);
        void GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppEndpoint);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice
    {
        void Activate([MarshalAs(UnmanagedType.LPStruct)] Guid iid, uint dwClsCtx,
            IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        void OpenPropertyStore(uint stgmAccess, out object ppProperties);
        void GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        void GetState(out uint pdwState);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolume
    {
        void RegisterControlChangeNotify(IntPtr notify);
        void UnregisterControlChangeNotify(IntPtr notify);
        void GetChannelCount(out uint pnChannelCount);
        void SetMasterVolumeLevel(float fLevelDB, [MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void SetMasterVolumeLevelScalar(float fLevel, [MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void GetMasterVolumeLevel(out float pfLevelDB);
        void GetMasterVolumeLevelScalar(out float pfLevel);
        void SetChannelVolumeLevel(uint nChannel, float fLevelDB, [MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void SetChannelVolumeLevelScalar(uint nChannel, float fLevel, [MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
        void GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
        void SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, [MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
        void GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
        void VolumeStepUp([MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void VolumeStepDown([MarshalAs(UnmanagedType.LPStruct)] ref Guid pguidEventContext);
        void QueryHardwareSupport(out uint pdwHardwareSupportMask);
        void GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
    }
}
