import 'package:flutter/material.dart';

class TextUtils {
  static TextDirection getTextDirection(String? text) {
    if (text == null || text.isEmpty) return TextDirection.ltr;
    // Check for Hebrew and Arabic characters, including Arabic extended blocks.
    final rtlRegex = RegExp(
      r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u0870-\u089F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    );
    return rtlRegex.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }
}
