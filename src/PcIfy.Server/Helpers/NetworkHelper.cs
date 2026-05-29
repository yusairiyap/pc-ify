using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace PcIfy.Server.Helpers;

public static class NetworkHelper
{
    /// <summary>
    /// Returns all active LAN IPv4 addresses (Wi-Fi + Ethernet), excluding loopback and link-local.
    /// </summary>
    public static IReadOnlyList<string> GetLocalIpAddresses()
    {
        var results = new List<string>();

        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType is NetworkInterfaceType.Loopback
                                         or NetworkInterfaceType.Tunnel) continue;

            foreach (var addr in nic.GetIPProperties().UnicastAddresses)
            {
                if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                var ip = addr.Address.ToString();
                if (ip.StartsWith("169.254")) continue; // skip link-local
                results.Add(ip);
            }
        }

        return results;
    }

    /// <summary>Returns the single best LAN IP, or null if none found.</summary>
    public static string? GetPrimaryLocalIp() =>
        GetLocalIpAddresses().FirstOrDefault();
}
