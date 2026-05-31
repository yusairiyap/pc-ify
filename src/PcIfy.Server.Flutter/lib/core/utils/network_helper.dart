import 'dart:io';

abstract final class NetworkHelper {
  static Future<List<String>> getLanIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      return interfaces
          .expand((i) => i.addresses)
          .where((a) =>
              !a.isLoopback &&
              !a.address.startsWith('169.254') && // link-local
              !a.address.startsWith('127.'))
          .map((a) => a.address)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getPrimaryLanIp() async {
    final ips = await getLanIpAddresses();
    return ips.isEmpty ? null : ips.first;
  }
}
