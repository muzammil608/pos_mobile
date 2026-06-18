import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

class ThermalReceiptData {
  final String companyName;
  final String phone;
  final String email;
  final String website;
  final String servedBy;
  final String customerName;
  final List<Map<String, dynamic>> items;
  final double total;
  final double cash;
  final double change;
  final double tax;
  final String paymentMethod;
  final String orderNo;
  final String date;

  const ThermalReceiptData({
    required this.companyName,
    required this.phone,
    required this.email,
    required this.website,
    required this.servedBy,
    required this.customerName,
    required this.items,
    required this.total,
    required this.cash,
    required this.change,
    required this.tax,
    required this.paymentMethod,
    required this.orderNo,
    required this.date,
  });
}

class ThermalPrinterService {
  ThermalPrinterService._();

  static final ThermalPrinterService instance = ThermalPrinterService._();

  final PrinterManager _manager = PrinterManager();

  Future<void> printReceiptAuto(
    ThermalReceiptData data,
  ) async {
    await _printReceiptAuto(data);
  }

  Future<void> _printReceiptAuto(ThermalReceiptData data) async {
    try {
      final printer = await _pickPrinterAuto();
      if (printer == null) return;

      await _manager.connect(printer);
      final ticket = await _buildTicket(data);
      await _manager.printTicket(ticket);
    } catch (_) {
    } finally {
      try {
        if (_manager.isConnected) {
          await _manager.disconnect();
        }
      } catch (_) {}
    }
  }

  Future<PrinterDevice?> _pickPrinterAuto() async {
    if (kIsWeb) return null;

    final printers = await _manager.scanPrinters(
      timeout: const Duration(seconds: 2),
      types: _supportedScanTypes(),
    );

    if (printers.isEmpty) {
      return null;
    }

    final supportedPrinters =
        printers.where(_isSupportedPrinterDevice).toList(growable: false);

    if (supportedPrinters.isEmpty) {
      return null;
    }

    return supportedPrinters.first;
  }

  Future<Ticket> _buildTicket(ThermalReceiptData data) async {
    final ticket = await Ticket.create(PaperSize.mm80);
    final subtotal = data.total - data.tax;

    final logo = await _loadLogo();
    if (logo != null) {
      ticket.imageRaster(logo, align: PrintAlign.center, maxWidth: 420);
      ticket.feed(1);
    }

    ticket.text(
      data.companyName,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true, height: TextSize.size2),
    );
    ticket.text('Tel: ${data.phone}', align: PrintAlign.center);
    ticket.text(data.email, align: PrintAlign.center);
    ticket.text(data.website, align: PrintAlign.center);
    ticket.feed(1);
    ticket.separator();
    ticket.text('Served by: ${data.servedBy}');
    ticket.text('Customer: ${data.customerName}');
    ticket.text('Order: ${data.orderNo}');
    ticket.text('Date: ${data.date}');
    ticket.separator();
    ticket.row([
      PrintColumn(
        text: 'ITEM',
        flex: 5,
        style: PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: 'QTY',
        flex: 2,
        align: PrintAlign.center,
        style: PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: 'TOTAL',
        flex: 3,
        align: PrintAlign.right,
        style: PrintTextStyle(bold: true),
      ),
    ]);
    ticket.separator();

    for (final item in data.items) {
      final name = item['name']?.toString() ?? 'Item';
      final qty = (item['qty'] as num?)?.toInt() ??
          (item['quantity'] as num?)?.toInt() ??
          1;
      final unitPrice =
          ((item['unitPrice'] ?? item['price']) as num?)?.toDouble() ?? 0.0;
      final lineTotal = ((item['lineTotal']) as num?)?.toDouble() ??
          (qty * unitPrice).toDouble();

      ticket.text(
        name,
        style: const PrintTextStyle(bold: true),
      );
      ticket.row([
        PrintColumn(
          text: 'Rs ${unitPrice.toStringAsFixed(2)} each',
          flex: 5,
        ),
        PrintColumn(
          text: '$qty',
          flex: 2,
          align: PrintAlign.center,
        ),
        PrintColumn(
          text: lineTotal.toStringAsFixed(2),
          flex: 3,
          align: PrintAlign.right,
        ),
      ]);
      ticket.feed(1);
    }

    ticket.separator();
    ticket.row([
      PrintColumn(text: 'Subtotal', flex: 1),
      PrintColumn(
        text: 'Rs ${subtotal.toStringAsFixed(2)}',
        flex: 1,
        align: PrintAlign.right,
      ),
    ]);
    ticket.row([
      PrintColumn(text: 'Tax', flex: 1),
      PrintColumn(
        text: 'Rs ${data.tax.toStringAsFixed(2)}',
        flex: 1,
        align: PrintAlign.right,
      ),
    ]);
    ticket.row([
      PrintColumn(
        text: 'TOTAL',
        flex: 1,
        style: PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: 'Rs ${data.total.toStringAsFixed(2)}',
        flex: 1,
        align: PrintAlign.right,
        style: const PrintTextStyle(bold: true),
      ),
    ]);

    if (data.paymentMethod == 'cash') {
      ticket.row([
        PrintColumn(text: 'Cash', flex: 1),
        PrintColumn(
          text: 'Rs ${data.cash.toStringAsFixed(2)}',
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);
      ticket.row([
        PrintColumn(
          text: 'CHANGE',
          flex: 1,
          style: PrintTextStyle(bold: true),
        ),
        PrintColumn(
          text: 'Rs ${data.change.toStringAsFixed(2)}',
          flex: 1,
          align: PrintAlign.right,
          style: const PrintTextStyle(bold: true),
        ),
      ]);
    } else if (data.paymentMethod == 'partial') {
      final dueLater = (data.total - data.cash).clamp(0, double.infinity);
      ticket.row([
        PrintColumn(text: 'Paid Now', flex: 1),
        PrintColumn(
          text: 'Rs ${data.cash.toStringAsFixed(2)}',
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);
      ticket.row([
        PrintColumn(
          text: 'DUE LATER',
          flex: 1,
          style: PrintTextStyle(bold: true),
        ),
        PrintColumn(
          text: 'Rs ${dueLater.toStringAsFixed(2)}',
          flex: 1,
          align: PrintAlign.right,
          style: const PrintTextStyle(bold: true),
        ),
      ]);
    }

    ticket.feed(1);
    ticket.text(
      'Thank you for visiting us',
      align: PrintAlign.center,
    );
    ticket.text(
      'Powered by Orion Solutions Pakistan',
      align: PrintAlign.center,
    );
    ticket.cut();

    return ticket;
  }

  Future<img.Image?> _loadLogo() async {
    try {
      final ByteData bytes = await rootBundle.load(
        'assets/images/orion-pos-logo-v2.png',
      );
      return img.decodeImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  bool _isSupportedPrinterDevice(PrinterDevice device) {
    if (kIsWeb) return false;

    if (device is! UsbPrinterDevice) return true;

    if (Platform.isLinux) {
      return RegExp(r'^/dev/(ttyUSB|ttyACM|serial/)')
          .hasMatch(device.identifier);
    }

    if (Platform.isMacOS) {
      return RegExp(r'^/dev/(cu|tty)\.(usb|USB|usbserial|SLAB|wch|modem)')
          .hasMatch(device.identifier);
    }

    if (Platform.isWindows) {
      return RegExp(r'^COM\d+$', caseSensitive: false)
          .hasMatch(device.identifier);
    }

    return true;
  }

  Set<PrinterConnectionType> _supportedScanTypes() {
    if (kIsWeb) return const {};

    if (Platform.isAndroid) {
      return const {
        PrinterConnectionType.network,
        PrinterConnectionType.ble,
        PrinterConnectionType.bluetooth,
        PrinterConnectionType.usb,
      };
    }

    if (Platform.isWindows) {
      return const {
        PrinterConnectionType.network,
        PrinterConnectionType.bluetooth,
        PrinterConnectionType.usb,
      };
    }

    if (Platform.isLinux || Platform.isMacOS) {
      return const {
        PrinterConnectionType.network,
        PrinterConnectionType.usb,
        PrinterConnectionType.ble,
      };
    }

    return const {
      PrinterConnectionType.network,
      PrinterConnectionType.ble,
    };
  }
}
