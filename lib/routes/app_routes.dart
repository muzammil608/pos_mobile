import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/unauthorized_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/reports/admin_dashboard_screen.dart';
import '../screens/cart/checkout_screen.dart';
import '../screens/admin/employee_manager_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/repairs/repairs_screen.dart';
import '../core/utils/no_animation_route.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        '/login': (_) => const LoginScreen(),
        '/pos': (_) => const PosScreen(),
        '/products': (_) => const ProductsScreen(),
        '/checkout': (_) => const CheckoutScreen(),
        '/admin': (_) => const AdminDashboardScreen(),
        '/employees': (_) => const EmployeeManagerScreen(),
        '/inventory': (_) => const InventoryScreen(),
        '/repairs': (_) => const RepairsScreen(),
        '/unauthorized': (_) => const UnauthorizedScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder == null) return null;

    return NoAnimationPageRoute<void>(
      settings: settings,
      builder: builder,
    );
  }
}
