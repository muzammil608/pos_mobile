import '../../models/order_model.dart';
import 'order_service.dart';
import 'repair_service.dart';

class TodayOrderSummary {
  final double revenue;
  final int orderCount;
  final Map<String, int> flowStats;

  const TodayOrderSummary({
    required this.revenue,
    required this.orderCount,
    required this.flowStats,
  });
}

class ReportService {
  final String ownerId;
  late final OrderService _orders = OrderService(ownerId);
  late final RepairService _repairs = RepairService(ownerId);
  Stream<List<Order>>? _sharedOrdersStream;

  ReportService(this.ownerId);

  Stream<List<Order>> _getSharedOrdersStream() {
    return _sharedOrdersStream ??=
        _orders.getOrdersStream().asBroadcastStream();
  }

  DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _todayLocalDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Stream<TodayOrderSummary> getTodayOrderSummary() {
    return _getSharedOrdersStream().map((orders) {
      final today = _todayLocalDay();
      double revenue = 0.0;
      int orderCount = 0;
      final flowStats = <String, int>{
        'total': 0,
        'pending': 0,
        'ready': 0,
        'completed': 0,
      };

      for (final order in orders) {
        final orderDay = _localDay(order.createdAt);
        if (!orderDay.isAtSameMomentAs(today)) continue;

        revenue += order.total;
        orderCount++;
        flowStats['total'] = (flowStats['total'] ?? 0) + 1;
        flowStats[order.status] = (flowStats[order.status] ?? 0) + 1;
      }

      return TodayOrderSummary(
        revenue: revenue,
        orderCount: orderCount,
        flowStats: flowStats,
      );
    });
  }

  Stream<Map<String, int>> getOrderStatusStats() {
    return _getSharedOrdersStream().map((orders) {
      final stats = <String, int>{'pending': 0, 'ready': 0, 'completed': 0};
      for (final order in orders) {
        stats[order.status] = (stats[order.status] ?? 0) + 1;
      }
      return stats;
    });
  }

  Stream<double> getTodayRevenue() {
    return _getSharedOrdersStream().map((orders) {
      final today = _todayLocalDay();

      return orders.where((order) {
        return _localDay(order.createdAt).isAtSameMomentAs(today);
      }).fold<double>(0.0, (sum, order) => sum + order.total);
    });
  }

  Stream<int> getTodayOrderCount() {
    return _getSharedOrdersStream().map((orders) {
      final today = _todayLocalDay();

      return orders.where((order) {
        return _localDay(order.createdAt).isAtSameMomentAs(today);
      }).length;
    });
  }

  Stream<double> getTodayRepairProfit() {
    return _repairs.getRepairsStream().map((repairs) {
      final today = _todayLocalDay();

      return repairs.where((repair) {
        if (repair.status != 'completed') return false;
        final completedAt = repair.completedDate ?? repair.createdAt;
        return _localDay(completedAt).isAtSameMomentAs(today);
      }).fold<double>(0, (sum, repair) => sum + repair.profit);
    });
  }

  Stream<Map<String, int>> getTodayOrderFlowStats() {
    return _getSharedOrdersStream().map((orders) {
      final today = _todayLocalDay();
      final stats = <String, int>{
        'total': 0,
        'pending': 0,
        'ready': 0,
        'completed': 0,
      };

      for (final order in orders) {
        final orderDay = _localDay(order.createdAt);
        if (!orderDay.isAtSameMomentAs(today)) continue;

        stats['total'] = (stats['total'] ?? 0) + 1;
        stats[order.status] = (stats[order.status] ?? 0) + 1;
      }

      return stats;
    });
  }

  Stream<List<Map<String, dynamic>>> getOrdersByPeriod(String period) {
    return _getSharedOrdersStream().map((orders) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = switch (period) {
        'weekly' => today.subtract(Duration(days: now.weekday - 1)),
        'monthly' => DateTime(now.year, now.month),
        'yearly' => DateTime(now.year),
        _ => today,
      };

      final filteredOrders = orders
          .where((order) => !_localDay(order.createdAt).isBefore(start))
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
