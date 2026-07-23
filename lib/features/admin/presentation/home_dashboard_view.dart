import 'package:flutter/material.dart';
import '../../../core/utils/responsive_layout.dart';

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
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );

    final double childAspectRatio = context.responsiveValue(
      mobile: 2.2,
      tablet: 1.5,
      desktop: 1.4,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel Principal',
            style: TextStyle(
              fontSize: context.isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1336),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenido a Gran Catador. Selecciona un módulo para comenzar.',
            style: TextStyle(
              fontSize: context.isMobile ? 14 : 18,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: context.isMobile ? 24 : 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: context.isMobile ? 16 : 32,
            mainAxisSpacing: context.isMobile ? 16 : 32,
            childAspectRatio: childAspectRatio,
            children: [
              _buildCard(context, 'Punto de Venta', Icons.point_of_sale, 1, Colors.blue),
              _buildCard(context, 'Stock / Inventario', Icons.warehouse, 4, Colors.orange),
              _buildCard(context, 'Productos', Icons.inventory_2, 2, Colors.purple),
              _buildCard(context, 'Clientes', Icons.people_alt, 5, Colors.indigo),
              _buildCard(context, 'Compras', Icons.shopping_cart_checkout, 6, Colors.teal),
              _buildCard(context, 'Cuentas por Cobrar', Icons.request_quote, 8, Colors.green),
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
    int destinationIndex,
    MaterialColor color,
  ) {
    final bool isMobile = context.isMobile;

    return InkWell(
      onTap: () => onNavigate(destinationIndex),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.shade100, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isMobile
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.shade50,
                    child: Icon(icon, size: 26, color: color.shade700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1336),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color.shade400),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: color.shade50,
                    child: Icon(icon, size: 36, color: color.shade700),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1336),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
