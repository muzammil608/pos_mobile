import 'order_service.dart';
import 'repair_service.dart';

class ReportService {
  final String ownerId;
  late final OrderService _orders = OrderService(ownerId);
  late final RepairService _repairs = RepairService(ownerId);

  ReportService(this.ownerId);

  Stream<Map<String, int>> getOrderStatusStats() {
    return _orders.getOrdersStream().map((orders) {
      final stats = <String, int>{'pending': 0, 'ready': 0, 'completed': 0};
      for (final order in orders) {
        stats[order.status] = (stats[order.status] ?? 0) + 1;
      }
      return stats;
    });
  }

  Stream<double> getTodayRevenue() {
    return _orders.getOrdersStream().map((orders) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return orders.where((order) {
        final date = order.createdAt;
        return DateTime(date.year, date.month, date.day)
            .isAtSameMomentAs(today);
      }).fold<double>(0.0, (sum, order) => sum + order.total);
    });
  }

  Stream<int> getTodayOrderCount() {
    return _orders.getOrdersStream().map((orders) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return orders.where((order) {
        final date = order.createdAt;
        return DateTime(date.year, date.month, date.day)
            .isAtSameMomentAs(today);
      }).length;
    });
  }

  Stream<double> getTodayRepairProfit() {
    return _repairs.getRepairsStream().map((repairs) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return repairs.where((repair) {
        if (repair.status != 'completed') return false;
        final completedAt = repair.completedDate ?? repair.createdAt;
        final completedDay = DateTime(
          completedAt.year,
          completedAt.month,
          completedAt.day,
        );
        return completedDay.isAtSameMomentAs(today);
      }).fold<double>(0, (sum, repair) => sum + repair.profit);
    });
  }

  Stream<Map<String, int>> getTodayOrderFlowStats() {
    return _orders.getOrdersStream().map((orders) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final stats = <String, int>{
        'total': 0,
        'pending': 0,
        'ready': 0,
        'completed': 0,
      };

      for (final order in orders) {
        final date = order.createdAt;
        final orderDay = DateTime(date.year, date.month, date.day);
        if (!orderDay.isAtSameMomentAs(today)) continue;

        stats['total'] = (stats['total'] ?? 0) + 1;
        stats[order.status] = (stats[order.status] ?? 0) + 1;
      }

      return stats;
    });
  }

  Stream<List<Map<String, dynamic>>> getOrdersByPeriod(String period) {
    return _orders.getOrdersStream().map((orders) {
      final now = DateTime.now();
      final start = switch (period) {
        'weekly' => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1)),
        'monthly' => DateTime(now.year, now.month),
        'yearly' => DateTime(now.year),
        _ => DateTime(now.year, now.month, now.day),
      };

      final filteredOrders = orders
          .where((order) => !order.createdAt.isBefore(start))
          .map(
            (order) => <String, dynamic>{
              ...order.toMap(),
              'id': order.id,
              'createdAtDate': order.createdAt,
            },
          )
          .toList();

      filteredOrders.sort(
        (a, b) => (b['createdAtDate'] as DateTime)
            .compareTo(a['createdAtDate'] as DateTime),
      );
      return filteredOrders;
    });
  }
}
