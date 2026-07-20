import 'package:flutter/material.dart';
import 'products_module_screen.dart';
import 'suppliers_module_screen.dart';
import 'inventory_management_screen.dart';
import 'print_inventory_screen.dart';
import 'purchases_module_screen.dart';
import 'accounts_payable_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ProductsModuleScreen(),
    const SuppliersModuleScreen(),
    const InventoryManagementScreen(),
    const PurchasesModuleScreen(),
    const AccountsPayableScreen(),
    const PrintInventoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1E1336),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            selectedIndex: _selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Productos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Proveedores'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse),
                label: Text('Stock / Inv.'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_cart_checkout_outlined),
                selectedIcon: Icon(Icons.shopping_cart_checkout),
                label: Text('Compras'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: Text('Cuentas x Pagar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.print_outlined),
                selectedIcon: Icon(Icons.print),
                label: Text('Reportes'),
              ),
            ],
            leading: Column(
              children: [
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Volver al POS',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}
