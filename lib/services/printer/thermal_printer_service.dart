import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../../models/repair_model.dart';

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

class ThermalRepairReceiptData {
  final String companyName;
  final String complaintPhone;
  final Repair repair;

  const ThermalRepairReceiptData({
    required this.companyName,
    required this.complaintPhone,
    required this.repair,
  });
}

class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ThermalPrinterService {
  ThermalPrinterService._();

  static final ThermalPrinterService instance = ThermalPrinterService._();

  static const int _thermalLogoWidth = 160;

  final PrinterManager _manager = PrinterManager();

  Future<void> printReceiptAuto(
    ThermalReceiptData data,
  ) async {
    await _printReceiptAuto(data);
  }

  Future<void> printRepairReceiptAuto(
    ThermalRepairReceiptData data,
  ) async {
    await _printRepairReceiptAuto(data);
  }

  Future<void> _printReceiptAuto(ThermalReceiptData data) async {
    if (!kIsWeb && Platform.isLinux) {
      final device = await _findLinuxUsbPrinterDevice();
      if (device != null &&
          await _printToLinuxUsbDevice(
            await _buildTicket(data),
            device,
          )) {
        return;
      }
    }

    try {
      final printer = await _pickPrinterAuto();

      await _manager.connect(printer);
      final ticket = await _buildTicket(data);
      await _manager.printTicket(ticket);
    } finally {
      try {
        if (_manager.isConnected) {
          await _manager.disconnect();
        }
      } catch (_) {}
    }
  }

  Future<void> _printRepairReceiptAuto(ThermalRepairReceiptData data) async {
    if (!kIsWeb && Platform.isLinux) {
      final device = await _findLinuxUsbPrinterDevice();
      if (device != null &&
          await _printToLinuxUsbDevice(
            await _buildRepairTicket(data),
            device,
          )) {
        return;
      }
    }

    try {
      final printer = await _pickPrinterAuto();

      await _manager.connect(printer);
      final ticket = await _buildRepairTicket(data);
      await _manager.printTicket(ticket);
    } finally {
      try {
        if (_manager.isConnected) {
          await _manager.disconnect();
        }
      } catch (_) {}
    }
  }

  Future<PrinterDevice> _pickPrinterAuto() async {
    if (kIsWeb) {
      throw const ThermalPrinterException(
        'Direct thermal printing is not available on web.',
      );
    }

    final printers = await _manager.scanPrinters(
      timeout: const Duration(seconds: 2),
      types: _supportedScanTypes(),
    );

    if (printers.isEmpty) {
      throw const ThermalPrinterException(
        'No printer found. Check that the thermal printer is connected and on.',
      );
    }

    final supportedPrinters =
        printers.where(_isSupportedPrinterDevice).toList(growable: false);

    if (supportedPrinters.isEmpty) {
      throw const ThermalPrinterException(
        'No supported thermal printer was found.',
      );
    }

    supportedPrinters.sort(
      (a, b) => _printerPriority(a).compareTo(_printerPriority(b)),
    );
    return supportedPrinters.first;
  }

  Future<File?> _findLinuxUsbPrinterDevice() async {
    if (kIsWeb || !Platform.isLinux) return null;
    for (var index = 0; index < 10; index++) {
      final candidate = File('/dev/usb/lp$index');
      if (await candidate.exists()) return candidate;
    }
    return null;
  }

  Future<bool> _printToLinuxUsbDevice(
    Ticket ticket,
    File printerDevice,
  ) async {
    if (kIsWeb || !Platform.isLinux) return false;

    RandomAccessFile? output;
    try {
      // Character devices cannot be truncated. FileMode.write requests a
      // truncate operation, which some USB printer drivers reject with EINVAL.
      output = await printerDevice.open(mode: FileMode.writeOnly);
      await output.writeFrom(ticket.bytes);
      await output.flush();
      return true;
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 13) {
        throw ThermalPrinterException(
          'Printer detected at ${printerDevice.path}, but access was denied. '
          'Add this Linux user to the lp group, then sign out and back in.',
        );
      }
      throw ThermalPrinterException(
        'Could not write to ${printerDevice.path}: '
        '${error.osError?.message ?? error.message}',
      );
    } finally {
      await output?.close();
    }
  }

  Future<Ticket> _buildTicket(ThermalReceiptData data) async {
    final ticket = await Ticket.create(PaperSize.mm80);
    final subtotal = data.total - data.tax;

    final logo = await _loadLogo();
    if (logo != null) {
      ticket.imageRaster(
        logo,
        align: PrintAlign.center,
        maxWidth: _thermalLogoWidth,
      );
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
    // Advance the footer beyond the cutter so it stays on this receipt.
    ticket.cut(linesBefore: 5);

    return ticket;
  }

  Future<Ticket> _buildRepairTicket(ThermalRepairReceiptData data) async {
    final repair = data.repair;
    final ticket = await Ticket.create(PaperSize.mm80);

    final logo = await _loadLogo();
    if (logo != null) {
      ticket.imageRaster(
        logo,
        align: PrintAlign.center,
        maxWidth: _thermalLogoWidth,
      );
    }

    ticket.text(
      data.companyName,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true, height: TextSize.size2),
    );
    ticket.text('REPAIR RECEIPT', align: PrintAlign.center);
    ticket.text(repair.jobId, align: PrintAlign.center);
    ticket.feed(1);
    ticket.separator();
    _ticketLine(ticket, 'Customer', repair.customerName);
    _ticketLine(ticket, 'Phone', repair.customerPhone);
    _ticketLine(ticket, 'Device', repair.deviceName);
    _ticketLine(ticket, 'IMEI/Serial', repair.serialNumber);
    _ticketLine(ticket, 'Technician', repair.assignedTechnician);
    _ticketLine(ticket, 'Status', RepairStatus.label(repair.status));
    _ticketLine(ticket, 'Received', _formatTicketDate(repair.createdAt));
    if (repair.expectedDeliveryDate != null) {
      _ticketLine(
        ticket,
        'Expected',
        _formatTicketDate(repair.expectedDeliveryDate),
      );
    }
    if (repair.completedDate != null) {
      _ticketLine(
        ticket,
        'Completed',
        _formatTicketDate(repair.completedDate),
      );
    }
    ticket.separator();

    ticket.text('PROBLEM', style: const PrintTextStyle(bold: true));
    ticket.text(_ticketValue(repair.problemDescription));
    if (repair.technicianNotes.trim().isNotEmpty) {
      ticket.feed(1);
      ticket.text('REPAIR WORK', style: const PrintTextStyle(bold: true));
      ticket.text(repair.technicianNotes.trim());
    }

    ticket.separator();
    ticket.separator();
    ticket.row([
      PrintColumn(
        text: 'TOTAL',
        flex: 6,
        style: const PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: 'Rs ${repair.estimatedCost.toStringAsFixed(2)}',
        flex: 4,
        align: PrintAlign.right,
        style: const PrintTextStyle(bold: true),
      ),
    ]);
    ticket.row([
      PrintColumn(text: 'Paid', flex: 6),
      PrintColumn(
        text: 'Rs ${repair.advancePayment.toStringAsFixed(2)}',
        flex: 4,
        align: PrintAlign.right,
      ),
    ]);
    ticket.row([
      PrintColumn(
        text: 'BALANCE',
        flex: 6,
        style: const PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: 'Rs ${repair.remainingBalance.toStringAsFixed(2)}',
        flex: 4,
        align: PrintAlign.right,
        style: const PrintTextStyle(bold: true),
      ),
    ]);
    _ticketLine(ticket, 'Payment', repair.paymentStatus);

    ticket.feed(1);
    ticket.text(
      'For info and complaints ${data.complaintPhone}',
      align: PrintAlign.center,
    );
    ticket.text(
      'Thank you for choosing ${data.companyName}',
      align: PrintAlign.center,
    );
    ticket.cut(linesBefore: 5);

    return ticket;
  }

  Future<img.Image?> _loadLogo() async {
    try {
      final ByteData bytes = await rootBundle.load(
        'assets/images/orion-pos-logo-v2.png',
      );
      final decoded = img.decodeImage(bytes.buffer.asUint8List());
      if (decoded == null) return null;

      // Thermal rasterization treats transparent pixels as black. Flatten the
      // PNG onto opaque white so only the logo artwork is printed.
      final flattened = img.Image(
        width: decoded.width,
        height: decoded.height,
        numChannels: 4,
      );
      img.fill(flattened, color: img.ColorUint8.rgb(255, 255, 255));
      img.compositeImage(flattened, decoded);
      return flattened;
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
      final queueName = '${device.name} ${device.identifier}'.toLowerCase();
      const virtualPrinterNames = <String>[
        'pdf',
        'xps',
        'onenote',
        'fax',
        'document writer',
      ];
      return !virtualPrinterNames.any(queueName.contains);
    }

    return true;
  }

  int _printerPriority(PrinterDevice device) {
    return switch (device.connectionType) {
      PrinterConnectionType.usb => 0,
      PrinterConnectionType.bluetooth => 1,
      PrinterConnectionType.ble => 2,
      PrinterConnectionType.network => 3,
    };
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
      if (Platform.isLinux) {
        return const {PrinterConnectionType.usb};
      }
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

  void _ticketLine(Ticket ticket, String label, String value) {
    ticket.row([
      PrintColumn(
        text: '$label:',
        flex: 4,
        style: const PrintTextStyle(bold: true),
      ),
      PrintColumn(
        text: _ticketValue(value),
        flex: 6,
        align: PrintAlign.right,
      ),
    ]);
  }

  String _ticketValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _formatTicketDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
