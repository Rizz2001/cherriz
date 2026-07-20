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
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> suppliers = [];
  String searchQuery = '';
  
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
      final catRes = await supabase.from('categories').select();
      final supRes = await supabase.from('suppliers').select();

      if (!mounted) return;

      setState(() {
        if (compRes.isNotEmpty) {
          company = compRes.first;
          _rateController.text =
              company!['exchange_rate']?.toString() ?? '40.00';
        }
        categories = List<Map<String, dynamic>>.from(catRes);
        suppliers = List<Map<String, dynamic>>.from(supRes);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando datos: $e', isError: true);
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      searchQuery = query;
    });
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
    final barcodeController = TextEditingController(
      text: isEditing ? (product['barcode']?.toString() ?? '') : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? product['price_usd']?.toString() : '',
    );
    final costController = TextEditingController(
      text: isEditing ? product['cost_usd']?.toString() : '',
    );
    final marginController = TextEditingController(
      text: isEditing ? product['margin_percent']?.toString() : '',
    );
    final unitsPerBoxController = TextEditingController(
      text: isEditing ? (product['units_per_box']?.toString() ?? '1') : '1',
    );
    final weightController = TextEditingController(
      text: isEditing ? (product['weight_grams']?.toString() ?? '') : '',
    );
    
    String? selectedCategoryId = isEditing ? product['category_id']?.toString() : null;
    String? selectedSupplierId = isEditing ? product['supplier_id']?.toString() : null;
    bool isSuspended = isEditing ? (product['is_suspended'] == true) : false;
    
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
                                labelText: 'SKU',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Código de Barras',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                                border: OutlineInputBorder(),
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['id'].toString(),
                                  child: Text(cat['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() => selectedCategoryId = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSupplierId,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor',
                                border: OutlineInputBorder(),
                              ),
                              items: suppliers.map((sup) {
                                return DropdownMenuItem<String>(
                                  value: sup['id'].toString(),
                                  child: Text(sup['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() => selectedSupplierId = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Costo USD',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                              onChanged: (val) {
                                final cost = double.tryParse(val) ?? 0;
                                final margin = double.tryParse(marginController.text) ?? 0;
                                if (cost > 0) {
                                  priceController.text = (cost + (cost * margin / 100)).toStringAsFixed(2);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: marginController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Margen %',
                                border: OutlineInputBorder(),
                                suffixText: '%',
                              ),
                              onChanged: (val) {
                                final cost = double.tryParse(costController.text) ?? 0;
                                final margin = double.tryParse(val) ?? 0;
                                if (cost > 0) {
                                  priceController.text = (cost + (cost * margin / 100)).toStringAsFixed(2);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Precio USD',
                                border: OutlineInputBorder(),
                                prefixText: '\$ ',
                              ),
                              onChanged: (val) {
                                final cost = double.tryParse(costController.text) ?? 0;
                                final price = double.tryParse(val) ?? 0;
                                if (cost > 0) {
                                  marginController.text = (((price - cost) / cost) * 100).toStringAsFixed(2);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnitType,
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: unitsPerBoxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Unidades por Caja',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Peso (Gramos)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Producto Suspendido / Descontinuado'),
                        value: isSuspended,
                        onChanged: (val) {
                          setModalState(() => isSuspended = val);
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
                                    final barcode = barcodeController.text.trim();
                                    final cost = double.tryParse(costController.text.trim());
                                    final margin = double.tryParse(marginController.text.trim());
                                    final unitsPerBox = int.tryParse(unitsPerBoxController.text.trim()) ?? 1;
                                    final weightGrams = double.tryParse(weightController.text.trim());

                                    if (name.isEmpty || price == null) {
                                      _showSnackBar(
                                        'Por favor ingresa nombre y precio al menos',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    try {
                                      final companyId = company?['id'];
                                      if (companyId == null) {
                                        throw Exception(
                                          'No se encontró la compañía actual',
                                        );
                                      }

                                      // Al vender en el módulo POS, si el usuario selecciona 'Vender por Caja', 
                                      // la cantidad a descontar del inventario general será: (cantidad_de_cajas * units_per_box)
                                      final productData = {
                                        'company_id': companyId,
                                        'name': name,
                                        'sku': sku,
                                        'barcode': barcode,
                                        'category_id': selectedCategoryId,
                                        'supplier_id': selectedSupplierId,
                                        'cost_usd': cost,
                                        'margin_percent': margin,
                                        'price_usd': price,
                                        'unit_type': selectedUnitType,
                                        if (!isEditing) 'stock': 0,
                                        'units_per_box': unitsPerBox,
                                        'weight_grams': weightGrams,
                                        'is_suspended': isSuspended,
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

                                      if (!dialogContext.mounted) return;
                                      Navigator.of(dialogContext).pop();
                                      _showSnackBar(
                                        isEditing
                                            ? 'Producto actualizado exitosamente'
                                            : 'Producto creado exitosamente',
                                      );
                                      // _fetchData() removido por Stream
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
      // _fetchData() removido por Stream
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _updateSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o código de barras...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                                rows: filteredProducts.map((prod) {
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
                      );
                    },
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
