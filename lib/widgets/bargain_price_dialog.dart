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
    if (salePrice <= 0) return 0;
    final discountFloor = maxDiscountPercent > 0 && salePrice > 0
        ? salePrice * (1 - (maxDiscountPercent / 100))
        : 0.0;
    final floor = [
      1.0,
      purchasePrice,
      minSalePrice,
      discountFloor,
    ].reduce(math.max);
    return floor.clamp(1, salePrice).toDouble();
  }

  double get suggestedPrice {
    if (salePrice <= 0) return 0;
    final naturalDiscount = math.min(500.0, salePrice * 0.1);
    final suggested = salePrice - naturalDiscount;
    return math.max(allowedFloor, suggested).clamp(1, salePrice).toDouble();
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

  void _setPrice(double price) {
    if (widget.salePrice <= 0) return;
    final next = price.clamp(1, widget.salePrice).toDouble();
    setState(() {
      _controller.text = next.toStringAsFixed(0);
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final floor = widget.allowedFloor;
    final currentPrice = double.tryParse(_controller.text.trim());
    final discount = currentPrice == null
        ? 0.0
        : (widget.salePrice - currentPrice).clamp(0, widget.salePrice);
    final discountPercent =
        widget.salePrice > 0 ? (discount / widget.salePrice) * 100 : 0.0;
    final profitAfterBargain = currentPrice == null
        ? 0.0
        : (currentPrice - widget.purchasePrice).clamp(
            double.negativeInfinity,
            double.infinity,
          );
    final needsApproval = currentPrice != null && currentPrice < floor;

    return AlertDialog(
      backgroundColor: NovaColors.bgPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Bargain Price'),
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
                      label: 'Minimum',
                      value: floor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickPriceChip(
                  label: '-100',
                  onTap: () => _setPrice(widget.salePrice - 100),
                ),
                _QuickPriceChip(
                  label: '-250',
                  onTap: () => _setPrice(widget.salePrice - 250),
                ),
                _QuickPriceChip(
                  label: '-500',
                  onTap: () => _setPrice(widget.salePrice - 500),
                ),
                _QuickPriceChip(
                  label: 'Minimum',
                  onTap: () => _setPrice(floor),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: needsApproval
                    ? NovaColors.dangerLight
                    : NovaColors.bgSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: needsApproval
                      ? NovaColors.danger.withValues(alpha: 0.25)
                      : NovaColors.borderTertiary,
                ),
              ),
              child: Column(
                children: [
                  _BargainMetricRow(
                    label: 'Discount',
                    value:
                        'Rs ${discount.toStringAsFixed(0)} (${discountPercent.toStringAsFixed(1)}%)',
                  ),
                  const SizedBox(height: 6),
                  _BargainMetricRow(
                    label: 'Profit after bargain',
                    value: 'Rs ${profitAfterBargain.toStringAsFixed(0)}',
                    valueColor: profitAfterBargain >= 0
                        ? NovaColors.teal
                        : NovaColors.danger,
                  ),
                  if (needsApproval) ...[
                    const SizedBox(height: 6),
                    const _BargainMetricRow(
                      label: 'Status',
                      value: 'Needs admin approval',
                      valueColor: NovaColors.danger,
                    ),
                  ],
                ],
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

class _QuickPriceChip extends StatelessWidget {
  const _QuickPriceChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: NovaColors.bgSecondary,
      side: const BorderSide(color: NovaColors.borderTertiary),
      labelStyle: const TextStyle(
        color: NovaColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BargainMetricRow extends StatelessWidget {
  const _BargainMetricRow({
    required this.label,
    required this.value,
    this.valueColor = NovaColors.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
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
