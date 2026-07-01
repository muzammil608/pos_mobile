import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/receipt_fonts.dart';
import '../core/utils/app_notice.dart';
import '../services/printer/thermal_printer_service.dart';

class ReceiptDialog extends StatelessWidget {
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

  const ReceiptDialog({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    void printReceipt() => _printReceipt(context);
    void closeReceipt() => Navigator.pop(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.enter):
              const _ReceiptPrintIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter):
              const _ReceiptPrintIntent(),
          const SingleActivator(LogicalKeyboardKey.keyP):
              const _ReceiptPrintIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const _ReceiptCloseIntent(),
          const SingleActivator(LogicalKeyboardKey.keyC):
              const _ReceiptCloseIntent(),
        },
        child: Actions(
          actions: {
            _ReceiptPrintIntent: CallbackAction<_ReceiptPrintIntent>(
              onInvoke: (_) {
                printReceipt();
                return null;
              },
            ),
            _ReceiptCloseIntent: CallbackAction<_ReceiptCloseIntent>(
              onInvoke: (_) {
                closeReceipt();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Center(
              child: SingleChildScrollView(
                child: ReceiptWidget(
                  companyName: companyName,
                  phone: phone,
                  email: email,
                  website: website,
                  servedBy: servedBy,
                  customerName: customerName,
                  items: items,
                  total: total,
                  cash: cash,
                  change: change,
                  tax: tax,
                  paymentMethod: paymentMethod,
                  orderNo: orderNo,
                  date: date,
                  onPrint: printReceipt,
                  onClose: closeReceipt,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      await ThermalPrinterService.instance.printReceiptAuto(
        ThermalReceiptData(
          companyName: companyName,
          phone: phone,
          email: email,
          website: website,
          servedBy: servedBy,
          customerName: customerName,
          items: items,
          total: total,
          cash: cash,
          change: change,
          tax: tax,
          paymentMethod: paymentMethod,
          orderNo: orderNo,
          date: date,
        ),
      );
      if (!context.mounted) return;
      AppNotice.show(
        context,
        'Receipt sent to thermal printer.',
        type: AppNoticeType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      final printerMissing = e.toString().contains('No printer found');
      AppNotice.show(
        context,
        printerMissing ? 'Thermal printer is not connected.' : 'Print failed',
        subtitle: printerMissing ? null : e.toString(),
        type: printerMissing ? AppNoticeType.warning : AppNoticeType.error,
      );
    }
  }
}

class _ReceiptPrintIntent extends Intent {
  const _ReceiptPrintIntent();
}

class _ReceiptCloseIntent extends Intent {
  const _ReceiptCloseIntent();
}

class ReceiptWidget extends StatelessWidget {
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
  final VoidCallback onPrint;
  final VoidCallback onClose;

  const ReceiptWidget({
    super.key,
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
    required this.onPrint,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final showShortcutLabels = MediaQuery.sizeOf(context).width >= 600;
    final subtotal = total - tax;

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/receipt_logo_white.png',
              height: 82,
              width: 190,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.store, size: 40);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: _receiptTitleStyle,
          ),
          const SizedBox(height: 4),
          Text('Tel: $phone', style: _receiptMetaStyle),
          Text(email, style: _receiptMetaStyle),
          Text(website, style: _receiptMetaStyle),
          const SizedBox(height: 8),
          const _ReceiptDivider(),
          const SizedBox(height: 8),
          _infoLine('Served by', servedBy),
          _infoLine('Customer', customerName),
          _infoLine('Order', orderNo),
          _infoLine('Date', date),
          const SizedBox(height: 10),
          const _ReceiptDivider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'ITEM',
                  style: _receiptHeaderStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.center,
                  style: _receiptHeaderStyle,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: _receiptHeaderStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _ReceiptItemRow(item: item)),
          const SizedBox(height: 10),
          const _ReceiptDivider(),
          const SizedBox(height: 10),
          _amountLine('Subtotal', subtotal),
          _amountLine('Tax', tax),
          const SizedBox(height: 4),
          _amountLine('TOTAL', total, isBold: true),
          const SizedBox(height: 12),
          if (paymentMethod == 'cash') ...[
            _amountLine('Cash', cash),
            _amountLine('CHANGE', change),
            const SizedBox(height: 12),
          ] else if (paymentMethod == 'partial') ...[
            _amountLine('Paid Now', cash),
            _amountLine(
              'DUE LATER',
              (total - cash).clamp(0, double.infinity).toDouble(),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Thank you for visiting us',
            textAlign: TextAlign.center,
            style: _receiptMetaStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Orion Solutions Pakistan',
            textAlign: TextAlign.center,
            style: _receiptMetaStyle,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(showShortcutLabels ? 'Close (Esc)' : 'Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(showShortcutLabels ? 'Print (Enter)' : 'Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: _receiptMetaStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _receiptMetaStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountLine(String label, double value, {bool isBold = false}) {
    final style = NovaFonts.price(
      fontSize: isBold ? 13 : 12,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
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
}

class _ReceiptItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ReceiptItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Item';
    final qty = (item['qty'] as num?)?.toInt() ??
        (item['quantity'] as num?)?.toInt() ??
        1;
    final unitPrice =
        ((item['unitPrice'] ?? item['price']) as num?)?.toDouble() ?? 0.0;
    final lineTotal = ((item['lineTotal']) as num?)?.toDouble() ??
        (qty * unitPrice).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: _receiptItemStyle,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Rs ${unitPrice.toStringAsFixed(2)} each',
                  style: _receiptMetaStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: _receiptMetaStyle,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  lineTotal.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style:
                      _receiptMetaStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 8).floor();
        return Text(
          List.filled(dashCount, '-').join(),
          style: _receiptMetaStyle.copyWith(letterSpacing: 1.2),
          maxLines: 1,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

final TextStyle _receiptTitleStyle = NovaFonts.receipt(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.4,
);

final TextStyle _receiptMetaStyle = NovaFonts.receipt(
  fontSize: 11.5,
  color: Colors.black87,
  height: 1.3,
);

final TextStyle _receiptHeaderStyle =
    NovaFonts.receipt(fontSize: 12, fontWeight: FontWeight.w700);

final TextStyle _receiptItemStyle =
    NovaFonts.receipt(fontSize: 12, fontWeight: FontWeight.w600);
