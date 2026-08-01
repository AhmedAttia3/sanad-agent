import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalUrl(String? url) async {
  final uri = Uri.tryParse(url ?? '');
  if (uri != null) {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
