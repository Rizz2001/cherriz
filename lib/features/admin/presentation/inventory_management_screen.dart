import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Ajuste Manual: ${product['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ingrese la cantidad real de existencias:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo Stock',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final newStock = int.tryParse(stockController.text.trim());
                    if (newStock == null) {
                      _showSnackBar('Ingrese un número válido', isError: true);
                      return;
                    }
                    setModalState(() => isSaving = true);
                    await _updateStock(product['id'], newStock);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                  child: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Gestión de Inventario (Stock)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _updateSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Buscar producto por nombre o código...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase.from('products').stream(primaryKey: ['id']).eq('is_active', true).order('name'),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF281E59)));
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

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F9)),
                                columns: const [
                                  DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Stock Actual', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Ajuste Rápido', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                                color: isLowStock ? Colors.redAccent : Colors.green.shade700,
                                              ),
                                            ),
                                            Text(
                                              sueltas == 0
                                                  ? 'Equivale a: $cajas Cajas completas'
                                                  : 'Equivale a: $cajas Cajas y $sueltas sueltas',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isLowStock ? Colors.red.shade50 : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: isLowStock ? Colors.red.shade200 : Colors.green.shade200),
                                          ),
                                          child: Text(
                                            isLowStock ? 'Bajo (<24)' : 'Adecuado',
                                            style: TextStyle(
                                              color: isLowStock ? Colors.red.shade700 : Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                              onPressed: () => _updateStock(p['id'], (stock > 0 ? stock - 1 : 0)),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                              onPressed: () => _updateStock(p['id'], stock + 1),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_square, color: Colors.blue),
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
                          ),
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
