import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/app_logo_transparent.png');
  if (!file.existsSync()) {
    stdout.writeln('Error: assets/images/app_logo_transparent.png not found');
    return;
  }

  final bytes = file.readAsBytesSync();
  final original = img.decodePng(bytes);
  if (original == null) {
    stdout.writeln('Error: Failed to decode PNG image');
    return;
  }

  // Resize into multi-resolution icons for Windows (256, 128, 64, 48, 32, 16)
  final sizes = [256, 128, 64, 48, 32, 16];
  final images = <img.Image>[];

  for (final size in sizes) {
    final resized = img.copyResize(
      original,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    images.add(resized);
  }

  final icoEncoder = img.IcoEncoder();
  final icoBytes = icoEncoder.encodeImages(images);

  final outputFile = File('windows/runner/resources/app_icon.ico');
  outputFile.writeAsBytesSync(icoBytes);

  stdout.writeln('Successfully generated 32-bit RGBA transparent ICO: ${outputFile.path}');
}
