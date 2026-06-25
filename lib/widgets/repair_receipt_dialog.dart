import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/receipt_fonts.dart';
import '../models/repair_model.dart';
import '../services/printer/thermal_printer_service.dart';

const String _repairShopName = 'AZMAT MOBILE AND REPAIRING CENTER';
const String _repairComplaintPhone = '03488626699';

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
                        _repairShopName,
                        textAlign: TextAlign.center,
                        style: NovaFonts.receipt(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                        _section('Repair work', repair.technicianNotes),
                      const _ReceiptDivider(),
                      const SizedBox(height: 8),
                      _amount('Total', repair.estimatedCost, bold: true),
                      _amount('Paid', repair.advancePayment),
                      _amount(
                        'Balance',
                        repair.remainingBalance,
                        bold: true,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Payment: ${repair.paymentStatus.toUpperCase()}',
                        style: NovaFonts.receipt(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Status: ${RepairStatus.label(repair.status).toUpperCase()}',
                        style: NovaFonts.receipt(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'For info and complaints $_repairComplaintPhone',
                        textAlign: TextAlign.center,
                        style: NovaFonts.receipt(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Thank you for choosing $_repairShopName',
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

  Future<void> _print() async {
    await ThermalPrinterService.instance.printRepairReceiptAuto(
      ThermalRepairReceiptData(
        companyName: _repairShopName,
        complaintPhone: _repairComplaintPhone,
        repair: repair,
      ),
    );
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
