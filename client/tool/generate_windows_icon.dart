import 'dart:io';

import 'package:image/image.dart';

const _iconSizes = <int>[16, 24, 32, 48, 64, 128, 256];

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: fvm dart run tool/generate_windows_icon.dart '
      '<source.png> <output.ico>',
    );
    exitCode = 64;
    return;
  }

  final source = decodePng(File(arguments[0]).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode ${arguments[0]} as PNG.');
    exitCode = 65;
    return;
  }

  final icon = copyResize(
    source,
    width: _iconSizes.first,
    height: _iconSizes.first,
    interpolation: Interpolation.average,
  );
  for (final size in _iconSizes.skip(1)) {
    icon.addFrame(
      copyResize(
        source,
        width: size,
        height: size,
        interpolation: Interpolation.average,
      ),
    );
  }

  File(arguments[1])
    ..createSync(recursive: true)
    ..writeAsBytesSync(encodeIco(icon));
}
