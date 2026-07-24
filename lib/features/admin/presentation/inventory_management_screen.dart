import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_button.dart';
import '../../../core/widgets/cherriz_text_field.dart';
import '../../../core/widgets/cherriz_card.dart';
import '../../../core/widgets/cherriz_data_table.dart';
import '../../../core/widgets/cherriz_modal.dart';
import '../../../core/widgets/cherriz_badge.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final supabase = Supabase.instance.client;
  String searchQuery = '';

  void _updateSearchQuery(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      ),
    );
  }

  Future<void> _updateStock(String productId, int newStock) async {
    try {
      await supabase.from('products').update({'stock': newStock}).eq('id', productId);
      _showSnackBar('Stock actualizado');
    } catch (e) {
      _showSnackBar('Error al actualizar stock: $e', isError: true);
    }
  }

  Future<void> _showManualStockAdjustModal(Map<String, dynamic> product) async {
    final stockController = TextEditingController(text: product['stock']?.toString() ?? '0');
    bool isSaving = false;

    await CherrizModal.show(
      context: context,
      title: 'Ajuste Manual: ${product['name']}',
      content: StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingrese la cantidad real de existencias:'),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                labelText: 'Nuevo Stock',
                prefixIcon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CherrizButton(
                    text: 'Cancelar',
                    variant: CherrizButtonVariant.ghost,
                    onPressed: isSaving ? null : () => Navigator.pop(modalContext),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CherrizButton(
                    text: 'Actualizar',
                    isLoading: isSaving,
                    onPressed: isSaving ? null : () async {
                      final newStock = int.tryParse(stockController.text.trim());
                      if (newStock == null) {
                        _showSnackBar('Ingrese un número válido', isError: true);
                        return;
                      }
                      setModalState(() => isSaving = true);
                      await _updateStock(product['id'], newStock);
                      if (modalContext.mounted) Navigator.pop(modalContext);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text('Gestión de Inventario (Stock)'),
              automaticallyImplyLeading: false,
            ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CherrizTextField(
                    onChanged: _updateSearchQuery,
                    hintText: 'Buscar producto por nombre o código...',
                    prefixIcon: Icons.search,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('products').stream(primaryKey: ['id']).eq('is_active', true).order('name'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent));
                  }

                  final productsData = snapshot.data!;
                  final lowerQuery = searchQuery.toLowerCase();
                  final filteredProducts = searchQuery.isEmpty
                      ? productsData
                      : productsData.where((p) {
                          final nameMatch = (p['name']?.toString().toLowerCase() ?? '').contains(lowerQuery);
                          final barcodeMatch = (p['barcode']?.toString().toLowerCase() ?? '').contains(lowerQuery);
                          return nameMatch || barcodeMatch;
                        }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Center(child: Text('No hay productos encontrados', style: TextStyle(color: AppColors.textMuted)));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      if (isMobile) {
                        return ListView.separated(
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            final stock = (p['stock'] as num?)?.toInt() ?? 0;
                            final unitsPerBox = (p['units_per_box'] as num?)?.toInt() ?? 1;
                            final upb = unitsPerBox > 0 ? unitsPerBox : 1;
                            final cajas = stock ~/ upb;
                            final sueltas = stock % upb;
                            final isLowStock = stock < 24;

                            return CherrizCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['name'] ?? 'Sin nombre',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      CherrizBadge(
                                        text: isLowStock ? 'Bajo (<24)' : 'Adecuado',
                                        variant: isLowStock ? CherrizBadgeVariant.danger : CherrizBadgeVariant.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text('Código: ${p['barcode']?.toString() ?? '-'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total: $stock Unidades',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isLowStock ? AppColors.danger : AppColors.success,
                                            ),
                                          ),
                                          Text(
                                            sueltas == 0
                                                ? '$cajas Cajas completas'
                                                : '$cajas Cajas y $sueltas sueltas',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                            onPressed: () => _updateStock(p['id'], (stock > 0 ? stock - 1 : 0)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                            onPressed: () => _updateStock(p['id'], stock + 1),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_square, color: AppColors.primaryAccent),
                                            tooltip: 'Ajuste Manual',
                                            onPressed: () => _showManualStockAdjustModal(p),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      return CherrizCard(
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: double.infinity,
                          child: CherrizDataTable(
                            columns: const [
                              DataColumn(label: Text('Producto')),
                              DataColumn(label: Text('Código')),
                              DataColumn(label: Text('Stock Actual')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Ajuste Rápido')),
                            ],
                            rows: filteredProducts.map((p) {
                              final stock = (p['stock'] as num?)?.toInt() ?? 0;
                              final unitsPerBox = (p['units_per_box'] as num?)?.toInt() ?? 1;
                              final upb = unitsPerBox > 0 ? unitsPerBox : 1;
                              final cajas = stock ~/ upb;
                              final sueltas = stock % upb;
                              final isLowStock = stock < 24;

                              return DataRow(
                                cells: [
                                  DataCell(Text(p['name'] ?? 'Sin nombre')),
                                  DataCell(Text(p['barcode']?.toString() ?? '-')),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Total: $stock Unidades',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isLowStock ? AppColors.danger : AppColors.success,
                                          ),
                                        ),
                                        Text(
                                          sueltas == 0
                                              ? 'Equivale a: $cajas Cajas completas'
                                              : 'Equivale a: $cajas Cajas y $sueltas sueltas',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    CherrizBadge(
                                      text: isLowStock ? 'Bajo (<24)' : 'Adecuado',
                                      variant: isLowStock ? CherrizBadgeVariant.danger : CherrizBadgeVariant.success,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                          onPressed: () => _updateStock(p['id'], (stock > 0 ? stock - 1 : 0)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                          onPressed: () => _updateStock(p['id'], stock + 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_square, color: AppColors.primaryAccent),
                                          tooltip: 'Ajuste Manual',
                                          onPressed: () => _showManualStockAdjustModal(p),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
