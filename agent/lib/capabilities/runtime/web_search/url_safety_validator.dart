import 'dart:io';

class UrlSafetyValidator {
  /// Check if the given [urlString] is safe to fetch (prevents SSRF).
  ///
  /// Safe URLs must use http/https, have a non-empty host, and resolve to
  /// public IP addresses that are not loopback, private, link-local, or multicast.
  static Future<bool> isSafeUrl(String urlString) async {
    try {
      final uri = Uri.tryParse(urlString);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }

      final host = uri.host;
      if (host.isEmpty) {
        return false;
      }

      // Perform DNS lookup
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        return false;
      }

      for (final address in addresses) {
        if (address.isLoopback ||
            address.isLinkLocal ||
            address.isMulticast ||
            isPrivateAddress(address)) {
          return false;
        }
      }

      return true;
    } catch (_) {
      // Any exception (e.g., host lookup fails) results in unsafe/invalid URL
      return false;
    }
  }

  /// Determines if an IP address resides in a private IPv4 or IPv6 subnet.
  static bool isPrivateAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      if (bytes.length < 4) return false;
      final a = bytes[0];
      final b = bytes[1];

      // 10.0.0.0/8
      if (a == 10) return true;

      // 172.16.0.0/12 (172.16.0.0 to 172.31.255.255)
      if (a == 172 && b >= 16 && b <= 31) return true;

      // 192.168.0.0/16
      if (a == 192 && b == 168) return true;

      return false;
    } else if (address.type == InternetAddressType.IPv6) {
      if (bytes.isEmpty) return false;
      final firstByte = bytes[0];

      // ULA (Unique Local Address) starts with fc00::/7 (i.e. 0xfc or 0xfd)
      if ((firstByte & 0xfe) == 0xfc) return true;

      return false;
    }
    return false;
  }
}
