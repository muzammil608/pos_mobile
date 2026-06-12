import 'package:flutter/material.dart';

class IconHelper {
  static const List<IconData> fastFoodIcons = [
    Icons.phone_android,
    Icons.tablet_android,
    Icons.watch,
    Icons.headphones,
    Icons.cable,
    Icons.power,
    Icons.usb,
    Icons.laptop,
    Icons.tv,
    Icons.router,
    Icons.mouse,
    Icons.keyboard,
    Icons.speaker,
    Icons.camera_alt,
    Icons.memory,
    Icons.battery_charging_full,
    Icons.print,
    Icons.sd_card,
    Icons.devices,
  ];

  static IconData getDefaultIcon(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('phone') || lower.contains('smartphone')) {
      return Icons.phone_android;
    } else if (lower.contains('tablet') || lower.contains('pad')) {
      return Icons.tablet_android;
    } else if (lower.contains('watch') || lower.contains('wearable')) {
      return Icons.watch;
    } else if (lower.contains('audio') ||
        lower.contains('headphone') ||
        lower.contains('bud') ||
        lower.contains('speaker')) {
      return Icons.headphones;
    } else if (lower.contains('cable') ||
        lower.contains('power') ||
        lower.contains('charge')) {
      return Icons.cable;
    }

    return Icons.devices;
  }

  static IconData fromCodePoint(int codePoint) {
    for (final icon in fastFoodIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    return Icons.devices;
  }
}
