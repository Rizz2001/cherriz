import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsModuleScreen extends StatefulWidget {
  const ProductsModuleScreen({super.key});

  @override
  State<ProductsModuleScreen> createState() => _ProductsModuleScreenState();
}

class _ProductsModuleScreenState extends State<ProductsModuleScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic>? company;
  final TextEditingController _rateController = TextEditingController();
  bool isUpdatingRate = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final compRes = await supabase.from('companies').select().limit(1);
      final prodRes = await supabase
          .from('products')
          .select()
          .eq('is_active', true);

      if (!mounted) return;

      setState(() {
        if (compRes.isNotEmpty) {
          company = compRes.first;
          _rateController.text =
              company!['exchange_rate']?.toString() ?? '40.00';
        }
        products = List<Map<String, dynamic>>.from(prodRes);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando datos: $e', isError: true);
    }
  }

  Future<void> _updateExchangeRate() async {
    if (company == null) return;
    final newRate = double.tryParse(_rateController.text);
    if (newRate == null) {
      _showSnackBar('Ingrese un valor numérico válido', isError: true);
      return;
    }

    setState(() => isUpdatingRate = true);

    try {
      await supabase
          .from('companies')
          .update({'exchange_rate': newRate})
          .eq('id', company!['id']);

      _showSnackBar('Tasa de cambio actualizada exitosamente');
    } catch (e) {
      _showSnackBar('Error al actualizar: $e', isError: true);
    } finally {
      if (mounted) setState(() => isUpdatingRate = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showProductModal([Map<String, dynamic>? product]) async {
    final isEditing = product != null;
    final nameController = TextEditingController(
      text: isEditing ? product['name'] : '',
    );
    final skuController = TextEditingController(
      text: isEditing ? product['sku'] : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? product['price_usd'].toString() : '',
    );
    final stockController = TextEditingController(
      text: isEditing ? (product['stock']?.toString() ?? '0') : '',
    );
    String selectedCategory = isEditing
        ? (product['category'] ?? 'Viveres')
        : 'Viveres';
    String selectedUnitType = isEditing
        ? (product['unit_type']?.toString().toLowerCase() ?? 'unidad')
        : 'unidad';
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(32.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Editar Producto' : 'Nuevo Producto',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1336),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Producto',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: skuController,
                              decoration: const InputDecoration(
                                labelText: 'SKU / Código',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio en USD',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock (Existencias)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnitType,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Unidad',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'unidad',
                                  child: Text('Unidad'),
                                ),
                                DropdownMenuItem(
                                  value: 'caja',
                                  child: Text('Caja'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() => selectedUnitType = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Viveres',
                            child: Text('Viveres'),
                          ),
                          DropdownMenuItem(
                            value: 'Bebidas',
                            child: Text('Bebidas'),
                          ),
                          DropdownMenuItem(
                            value: 'Licores',
                            child: Text('Licores'),
                          ),
                          DropdownMenuItem(
                            value: 'Snacks',
                            child: Text('Snacks'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1336),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    final sku = skuController.text.trim();
                                    final price = double.tryParse(
                                      priceController.text.trim(),
                                    );
                                    final stock =
                                        int.tryParse(
                                          stockController.text.trim(),
                                        ) ??
                                        0;

                                    if (name.isEmpty ||
                                        sku.isEmpty ||
                                        price == null) {
                                      _showSnackBar(
                                        'Por favor completa todos los campos correctamente',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    try {
                                      final companyId = company?['id'];
                                      if (companyId == null)
                                        throw Exception(
                                          'No se encontró la compañía actual',
                                        );

                                      final productData = {
                                        'company_id': companyId,
                                        'name': name,
                                        'sku': sku,
                                        'category': selectedCategory,
                                        'price_usd': price,
                                        'unit_type': selectedUnitType,
                                        'stock': stock,
                                      };

                                      if (isEditing) {
                                        await supabase
                                            .from('products')
                                            .update(productData)
                                            .eq('id', product['id']);
                                      } else {
                                        await supabase
                                            .from('products')
                                            .insert(productData);
                                      }

                                      if (!mounted) return;
                                      Navigator.of(dialogContext).pop();
                                      _showSnackBar(
                                        isEditing
                                            ? 'Producto actualizado exitosamente'
                                            : 'Producto creado exitosamente',
                                      );
                                      _fetchData(); // Refrescar la tabla
                                    } catch (e) {
                                      setModalState(() => isSaving = false);
                                      _showSnackBar(
                                        'Error al crear producto: $e',
                                        isError: true,
                                      );
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? 'Actualizar Producto'
                                        : 'Guardar Producto',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Confirmar Eliminación',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1336),
            ),
          ),
          content: const Text('¿Seguro que desea eliminar este producto?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);
      _showSnackBar('Producto archivado exitosamente');
      _fetchData();
    } catch (e) {
      _showSnackBar('Error al eliminar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF281E59)),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección 1 - Tasa de Cambio
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.currency_exchange,
                            size: 40,
                            color: Color(0xFF281E59),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tasa de Cambio (Bs.)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1336),
                                  ),
                                ),
                                Text(
                                  'Usada para conversiones en POS',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: _rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Tasa Actual',
                                border: OutlineInputBorder(),
                                prefixText: 'Bs. ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1336),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isUpdatingRate
                                ? null
                                : _updateExchangeRate,
                            child: isUpdatingRate
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Actualizar Tasa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sección 2 - Inventario
                  const Text(
                    'Inventario de Productos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1336),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF4F6F9),
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'SKU / ID',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Nombre',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Categoría',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Precio USD',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Stock',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: products.map((prod) {
                              final price =
                                  (prod['price_usd'] as num?)?.toDouble() ??
                                  0.0;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      prod['id']?.toString().substring(0, 8) ??
                                          '-',
                                    ),
                                  ),
                                  DataCell(Text(prod['name'] ?? 'Sin nombre')),
                                  DataCell(
                                    Text(prod['category'] ?? 'Sin categoría'),
                                  ),
                                  DataCell(
                                    Text(
                                      '\$${price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF281E59),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(prod['stock']?.toString() ?? '0'),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              _showProductModal(prod),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteProduct(
                                            prod['id'].toString(),
                                          ),
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
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        onPressed: () => _showProductModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
