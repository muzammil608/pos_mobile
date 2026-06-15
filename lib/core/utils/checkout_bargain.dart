class CheckoutBargain {
  static const double maxAutomaticDiscount = 500;

  static double shortfall(double tendered, double total) {
    if (tendered <= 0 || tendered >= total) return 0;
    return total - tendered;
  }

  static bool isAutomatic(double tendered, double total) {
    final discount = shortfall(tendered, total);
    return discount > 0 && discount <= maxAutomaticDiscount;
  }

  static bool isInsufficient(double tendered, double total) {
    if (tendered <= 0) return true;
    return shortfall(tendered, total) > maxAutomaticDiscount;
  }

  static double orderTotal(double tendered, double total) {
    return isAutomatic(tendered, total) ? tendered : total;
  }

  static double change(double tendered, double total) {
    if (isAutomatic(tendered, total)) return 0;
    return tendered > total ? tendered - total : 0;
  }

  static List<Map<String, dynamic>> applyToItems(
    List<Map<String, dynamic>> items,
    double discount,
  ) {
    if (discount <= 0 || items.isEmpty) return items;

    final total = items.fold<double>(
      0,
      (sum, item) => sum + ((item['lineTotal'] as num?)?.toDouble() ?? 0),
    );
    if (total <= 0) return items;

    var remainingDiscount = discount;
    return List.generate(items.length, (index) {
      final item = items[index];
      final qty = (item['qty'] as num?)?.toInt() ??
          (item['quantity'] as num?)?.toInt() ??
          1;
      final originalUnitPrice = (item['price'] as num?)?.toDouble() ?? 0;
      final originalLineTotal = originalUnitPrice * qty;
      final allocated = index == items.length - 1
          ? remainingDiscount
          : discount * (originalLineTotal / total);
      remainingDiscount -= allocated;

      final lineTotal =
          (originalLineTotal - allocated).clamp(0, double.infinity);
      final unitPrice = qty > 0 ? lineTotal / qty : 0.0;
      final purchasePrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0;
      final discountPercent = originalUnitPrice > 0
          ? ((originalUnitPrice - unitPrice) / originalUnitPrice) * 100
          : 0.0;

      return {
        ...item,
        'price': unitPrice,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
        'originalPrice': originalUnitPrice,
        'discountPercent': discountPercent,
        'isBargained': true,
        'checkoutBargain': true,
        'unitProfit': unitPrice - purchasePrice,
        'lineProfit': (unitPrice - purchasePrice) * qty,
      };
    });
  }
}
