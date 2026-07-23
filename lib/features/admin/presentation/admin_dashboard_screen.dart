import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/responsive_layout.dart';
import 'products_module_screen.dart';
import 'suppliers_module_screen.dart';
import 'inventory_management_screen.dart';
import 'print_inventory_screen.dart';
import 'purchases_module_screen.dart';
import 'accounts_payable_screen.dart';
import 'customers_module_screen.dart';
import 'accounts_receivable_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import 'home_dashboard_view.dart';

class CashRegisterIntent extends Intent {
  const CashRegisterIntent();
}

class NavDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const List<NavDestinationItem> _navItems = [
  NavDestinationItem(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  NavDestinationItem(
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  NavDestinationItem(
    label: 'Productos',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  NavDestinationItem(
    label: 'Proveedores',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  NavDestinationItem(
    label: 'Stock / Inv.',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
  ),
  NavDestinationItem(
    label: 'Clientes',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
  ),
  NavDestinationItem(
    label: 'Compras',
    icon: Icons.shopping_cart_checkout_outlined,
    selectedIcon: Icons.shopping_cart_checkout,
  ),
  NavDestinationItem(
    label: 'Cuentas x Pagar',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  NavDestinationItem(
    label: 'Cuentas x Cobrar',
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote,
  ),
  NavDestinationItem(
    label: 'Reportes',
    icon: Icons.print_outlined,
    selectedIcon: Icons.print,
  ),
];

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeDashboardView(
        onNavigate: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      const POSScreen(),
      const ProductsModuleScreen(),
      const SuppliersModuleScreen(),
      const InventoryManagementScreen(),
      const CustomersModuleScreen(),
      const PurchasesModuleScreen(),
      const AccountsPayableScreen(),
      const AccountsReceivableScreen(),
      const PrintInventoryScreen(),
    ];
  }

  void setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f4): const CashRegisterIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CashRegisterIntent: CallbackAction<CashRegisterIntent>(
            onInvoke: (CashRegisterIntent intent) {
              setIndex(1); // POS Index
              return null;
            },
          ),
        },
        child: ResponsiveBuilder(
          mobile: _buildMobileLayout(context),
          tablet: _buildDesktopOrTabletLayout(context),
          desktop: _buildDesktopOrTabletLayout(context),
        ),
      ),
    );
  }

  /// Layout for Desktop and Tablet screens (Side NavigationRail)
  Widget _buildDesktopOrTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
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
                      destinations: _navItems
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            },
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

  /// Layout for Mobile screens (AppBar + Navigation Drawer + Bottom Navigation Bar)
  Widget _buildMobileLayout(BuildContext context) {
    // Map bottom bar items (Top 4 key modules + Drawer trigger)
    final int bottomBarSelectedIndex = _selectedIndex < 4 ? _selectedIndex : 4;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        title: Text(
          _navItems[_selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 2,
      ),
      drawer: _buildMobileDrawer(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          return BottomNavigationBar(
            currentIndex: bottomBarSelectedIndex,
            selectedItemColor: const Color(0xFF7E57C2),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 8,
            onTap: (index) {
              if (index == 4) {
                // Open Drawer for full navigation options
                Scaffold.of(context).openDrawer();
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale_outlined),
                activeIcon: Icon(Icons.point_of_sale),
                label: 'POS',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Productos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined),
                activeIcon: Icon(Icons.people_alt),
                label: 'Clientes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu),
                label: 'Menú',
              ),
            ],
          );
        }
      ),
    );
  }

  /// Navigation Drawer for Mobile view
  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1336), Color(0xFF281E59)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF7E57C2), Color(0xFF512DA8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cherriz ERP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Menú Principal',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = index == _selectedIndex;
                return ListTile(
                  leading: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? const Color(0xFF7E57C2) : Colors.black87,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF7E57C2) : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    Navigator.of(context).pop(); // Close drawer
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
