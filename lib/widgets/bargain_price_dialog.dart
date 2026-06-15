import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/nova_theme.dart';

class BargainPriceResult {
  final double price;
  final bool requiresAdminApproval;

  const BargainPriceResult({
    required this.price,
    required this.requiresAdminApproval,
  });
}

class BargainPriceDialog extends StatefulWidget {
  final String itemName;
  final double salePrice;
  final double purchasePrice;
  final double minSalePrice;
  final double maxDiscountPercent;
  final bool canApproveBelowFloor;

  const BargainPriceDialog({
    super.key,
    required this.itemName,
    required this.salePrice,
    required this.purchasePrice,
    required this.minSalePrice,
    required this.maxDiscountPercent,
    this.canApproveBelowFloor = false,
  });

  double get allowedFloor {
    return math.max(1, salePrice - 500).toDouble();
  }

  double get suggestedPrice {
    return allowedFloor;
  }

  @override
  State<BargainPriceDialog> createState() => _BargainPriceDialogState();
}

class _BargainPriceDialogState extends State<BargainPriceDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.suggestedPrice.toStringAsFixed(0),
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_controller.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price greater than zero.');
      return;
    }
    if (price > widget.salePrice) {
      setState(() => _error = 'Bargain price cannot exceed the sale price.');
      return;
    }
    if (price < widget.allowedFloor && !widget.canApproveBelowFloor) {
      setState(
        () => _error =
            'Minimum allowed is Rs ${widget.allowedFloor.toStringAsFixed(0)}. '
                'Admin approval is required for a lower price.',
      );
      return;
    }

    Navigator.pop(
      context,
      BargainPriceResult(
        price: price,
        requiresAdminApproval: price < widget.allowedFloor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floor = widget.allowedFloor;
    return AlertDialog(
      backgroundColor: NovaColors.bgPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Bargain Price'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.itemName,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NovaColors.violetLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PriceSummary(
                      label: 'Sale price',
                      value: widget.salePrice,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: NovaColors.borderSecondary,
                  ),
                  Expanded(
                    child: _PriceSummary(
                      label: 'Suggested',
                      value: widget.suggestedPrice,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Final bargain price',
                prefixText: 'Rs ',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allowed minimum: Rs ${floor.toStringAsFixed(0)}',
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Rs ${value.toStringAsFixed(0)}',
          style: const TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
