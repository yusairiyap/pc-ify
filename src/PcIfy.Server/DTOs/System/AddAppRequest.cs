namespace PcIfy.Server.DTOs.System;

public record AddAppRequest(string Name, string ExecutablePath, string? ProcessName, string? IconKey);
