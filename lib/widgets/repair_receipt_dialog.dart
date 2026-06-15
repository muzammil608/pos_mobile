import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme/receipt_fonts.dart';
import '../models/repair_model.dart';

class RepairReceiptDialog extends StatelessWidget {
  const RepairReceiptDialog({
    super.key,
    required this.repair,
  });

  final Repair repair;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter):
              _PrintRepairReceiptIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter):
              _PrintRepairReceiptIntent(),
          SingleActivator(LogicalKeyboardKey.escape):
              _CloseRepairReceiptIntent(),
        },
        child: Actions(
          actions: {
            _PrintRepairReceiptIntent:
                CallbackAction<_PrintRepairReceiptIntent>(
              onInvoke: (_) {
                _print();
                return null;
              },
            ),
            _CloseRepairReceiptIntent:
                CallbackAction<_CloseRepairReceiptIntent>(
              onInvoke: (_) {
                Navigator.pop(context);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/orion-pos-logo-v2.png',
                        height: 78,
                        width: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.build_circle_rounded, size: 46),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'REPAIR RECEIPT',
                        style: NovaFonts.receipt(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        repair.jobId,
                        style: NovaFonts.code(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      const _ReceiptDivider(),
                      const SizedBox(height: 8),
                      _line('Customer', repair.customerName),
                      _line('Phone', repair.customerPhone),
                      _line('Device', repair.deviceName),
                      _line('IMEI / Serial', repair.serialNumber),
                      _line('Technician', repair.assignedTechnician),
                      _line('Received', _formatReceiptDate(repair.createdAt)),
                      _line(
                        'Completed',
                        _formatReceiptDate(repair.completedDate),
                      ),
                      const SizedBox(height: 8),
                      const _ReceiptDivider(),
                      const SizedBox(height: 8),
                      _section('Problem', repair.problemDescription),
                      if (repair.technicianNotes.isNotEmpty)
                        _section('Technician notes', repair.technicianNotes),
                      if (repair.partsUsed.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'CHARGES',
                            style: NovaFonts.receipt(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...repair.partsUsed.map(_partCharge),
                      ],
                      _amount('Labour', repair.labourCost),
                      const _ReceiptDivider(),
                      const SizedBox(height: 8),
                      _amount('Total', repair.estimatedCost, bold: true),
                      _amount('Advance', repair.advancePayment),
                      _amount(
                        'Balance',
                        repair.remainingBalance,
                        bold: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Status: COMPLETED',
                        style: NovaFonts.receipt(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Thank you for choosing Orion POS',
                        textAlign: TextAlign.center,
                        style: NovaFonts.receipt(fontSize: 11),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _print,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('Print'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: NovaFonts.receipt(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: NovaFonts.receipt(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: NovaFonts.receipt(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: NovaFonts.receipt(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, double value, {bool bold = false}) {
    final style = NovaFonts.price(
      fontSize: bold ? 13 : 12,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _partCharge(RepairPart part) {
    final label =
        part.quantity > 1 ? '${part.name} ×${part.quantity}' : part.name;
    return _amount(label, part.saleTotal);
  }

  Future<void> _print() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          400 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'ORION POS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: pw.Font.courierBold(),
                fontSize: 16,
              ),
            ),
            pw.Text(
              'REPAIR RECEIPT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: pw.Font.courierBold(),
                fontSize: 13,
              ),
            ),
            pw.Text(
              repair.jobId,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 11),
            ),
            pw.Divider(),
            _pdfLine('Customer', repair.customerName),
            _pdfLine('Phone', repair.customerPhone),
            _pdfLine('Device', repair.deviceName),
            _pdfLine('IMEI / Serial', repair.serialNumber),
            _pdfLine('Technician', repair.assignedTechnician),
            _pdfLine('Received', _formatReceiptDate(repair.createdAt)),
            _pdfLine('Completed', _formatReceiptDate(repair.completedDate)),
            pw.Divider(),
            _pdfSection('Problem', repair.problemDescription),
            if (repair.technicianNotes.isNotEmpty)
              _pdfSection('Technician notes', repair.technicianNotes),
            if (repair.partsUsed.isNotEmpty) ...[
              pw.Text(
                'CHARGES',
                style: pw.TextStyle(
                  font: pw.Font.courierBold(),
                  fontSize: 9,
                ),
              ),
              pw.SizedBox(height: 3),
              ...repair.partsUsed.map(_pdfPartCharge),
            ],
            _pdfAmount('Labour', repair.labourCost),
            pw.Divider(),
            _pdfAmount('Total', repair.estimatedCost, bold: true),
            _pdfAmount('Advance', repair.advancePayment),
            _pdfAmount('Balance', repair.remainingBalance, bold: true),
            pw.SizedBox(height: 10),
            pw.Text(
              'STATUS: COMPLETED',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: pw.Font.courierBold(),
                fontSize: 11,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Thank you for choosing Orion POS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      name: 'repair_${repair.jobId}.pdf',
      onLayout: (_) async => pdf.save(),
    );
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: pw.Font.courierBold(),
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSection(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(font: pw.Font.courierBold(), fontSize: 9),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfAmount(String label, double value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: bold ? pw.Font.courierBold() : pw.Font.courier(),
              fontSize: bold ? 11 : 10,
            ),
          ),
          pw.Text(
            'Rs ${value.toStringAsFixed(2)}',
            style: pw.TextStyle(
              font: bold ? pw.Font.courierBold() : pw.Font.courier(),
              fontSize: bold ? 11 : 10,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfPartCharge(RepairPart part) {
    final label =
        part.quantity > 1 ? '${part.name} x${part.quantity}' : part.name;
    return _pdfAmount(label, part.saleTotal);
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        List.filled((constraints.maxWidth / 8).floor(), '-').join(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: NovaFonts.receipt(fontSize: 11, letterSpacing: 1.1),
      ),
    );
  }
}

class _PrintRepairReceiptIntent extends Intent {
  const _PrintRepairReceiptIntent();
}

class _CloseRepairReceiptIntent extends Intent {
  const _CloseRepairReceiptIntent();
}

String _formatReceiptDate(DateTime? date) {
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
