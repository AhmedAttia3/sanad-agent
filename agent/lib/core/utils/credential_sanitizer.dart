/// Sanitizes credential values by stripping non-ASCII characters that break
/// HTTP header encoding when keys are copy-pasted from rich-text sources.
///
/// This is the shared implementation used by both the CLI setup wizard and the
/// provider runtime services.
String sanitizeCredential(String value) {
  bool isAscii = true;
  for (int i = 0; i < value.length; i++) {
    if (value.codeUnitAt(i) > 127) {
      isAscii = false;
      break;
    }
  }
  if (isAscii) return value;

  final buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    final codeUnit = value.codeUnitAt(i);
    if (codeUnit <= 127) {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}
