import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(File('assets/images/app_icon.png').readAsBytesSync());
  if (source == null) throw StateError('Could not decode app icon.');

  const androidIcons = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  const iosIcons = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  for (final icon in androidIcons.entries) {
    _writeIcon(source, icon.key, icon.value);
  }
  for (final icon in iosIcons.entries) {
    _writeIcon(
      source,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/${icon.key}',
      icon.value,
    );
  }
}

void _writeIcon(img.Image source, String path, int size) {
  final resized = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  File(path).writeAsBytesSync(img.encodePng(resized, level: 9));
}
