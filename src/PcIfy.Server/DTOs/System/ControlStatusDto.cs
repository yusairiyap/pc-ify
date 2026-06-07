namespace PcIfy.Server.DTOs.System;

public record BatteryStatusDto(int Level, bool Charging, bool Available);
public record VolumeStatusDto(int Level, bool Muted, bool Available);
public record CpuStatusDto(double Usage, bool Available);
public record RamStatusDto(long UsedMb, long TotalMb, bool Available);
public record ScreenStatusDto(bool Locked, bool Available);
public record DiskStatusDto(long UsedBytes, long TotalBytes, bool Available);
public record ControlStatusDto(BatteryStatusDto Battery, VolumeStatusDto Volume, CpuStatusDto Cpu, RamStatusDto Ram, ScreenStatusDto Screen, DiskStatusDto Disk);
