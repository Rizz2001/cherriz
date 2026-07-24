import 'package:flutter/material.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_card.dart';
import 'company_profile_screen.dart';
import 'user_management_screen.dart';

class HomeDashboardView extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeDashboardView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final double padding = context.responsiveValue(
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final int crossAxisCount = context.responsiveValue(
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    final double childAspectRatio = context.responsiveValue(
      mobile: 1.1,
      tablet: 1.2,
      desktop: 1.3,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel Principal',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: context.isMobile ? 24 : 32,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bienvenido a Gran Catador. Selecciona un módulo para comenzar.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: context.isMobile ? 14 : 16,
                ),
          ),
          SizedBox(height: context.isMobile ? AppSpacing.lg : AppSpacing.xxl),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: context.isMobile ? 16 : 32,
            mainAxisSpacing: context.isMobile ? 16 : 32,
            childAspectRatio: childAspectRatio,
            children: [
              _buildCard(context, 'Punto de Venta', Icons.point_of_sale, Colors.blue, () => onNavigate(1)),
              _buildCard(context, 'Stock / Inventario', Icons.warehouse, Colors.orange, () => onNavigate(4)),
              _buildCard(context, 'Productos', Icons.inventory_2, Colors.purple, () => onNavigate(2)),
              _buildCard(context, 'Clientes', Icons.people_alt, Colors.indigo, () => onNavigate(5)),
              _buildCard(context, 'Compras', Icons.shopping_cart_checkout, Colors.teal, () => onNavigate(6)),
              _buildCard(context, 'Cuentas por Cobrar', Icons.request_quote, Colors.green, () => onNavigate(8)),
              _buildCard(context, 'Perfil de Empresa', Icons.storefront, Colors.blueGrey, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompanyProfileScreen(),
                  ),
                );
              }),
              _buildCard(context, 'Control de Usuarios', Icons.manage_accounts, Colors.deepOrange, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    MaterialColor color,
    VoidCallback onTap,
  ) {
    final bool isMobile = context.isMobile;

    return CherrizCard(
      onTap: onTap,
      padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: isMobile ? 20 : 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.04),
            child: Icon(icon, size: isMobile ? 22 : 28, color: AppColors.primaryAccent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: isMobile ? 12 : 14,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
