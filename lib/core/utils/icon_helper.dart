import 'package:flutter/material.dart';

class IconHelper {
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
}
