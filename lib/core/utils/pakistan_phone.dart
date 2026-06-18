import 'package:flutter/services.dart';

class PakistanPhone {
  const PakistanPhone._();

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String normalizeMobile(String value) {
    final digits = digitsOnly(value);
    if (digits.length == 11 && digits.startsWith('03')) return digits;
    if (digits.length == 12 && digits.startsWith('923')) {
      return '0${digits.substring(2)}';
    }
    return digits;
  }

  static bool isValidMobile(String value) {
    final normalized = normalizeMobile(value);
    return RegExp(r'^03\d{9}$').hasMatch(normalized);
  }

  static const String mobileHint = 'Use 03XXXXXXXXX or +923XXXXXXXXX.';
}

class PakistanMobileInputFormatter extends TextInputFormatter {
  const PakistanMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9+\-\s]'), '');

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
