import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/responsive_layout.dart';

class PurchasesModuleScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPurchase;

  const PurchasesModuleScreen({super.key, this.initialPurchase});

  @override
  State<PurchasesModuleScreen> createState() => _PurchasesModuleScreenState();
}

class _PurchasesModuleScreenState extends State<PurchasesModuleScreen> {
  final supabase = Supabase.instance.client;

  bool get isEditMode => widget.initialPurchase != null;
  String? editPurchaseId;

  bool isLoading = true;
  bool isProcessing = false;

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> searchResults = [];

  String? selectedSupplierId;
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _freightController = TextEditingController(text: '0.00');
  final TextEditingController _exchangeRateController = TextEditingController(text: '1.00');
  DateTime? purchaseDate = DateTime.now();
  DateTime? dueDate = DateTime.now().add(const Duration(days: 30));

  final TextEditingController _searchController = TextEditingController();

  double freightCost = 0.0;
  double exchangeRate = 1.0;

  // Cart items structure: { 'product_id', 'name', 'sku', 'quantity', 'unit_cost' }
  List<Map<String, dynamic>> cart = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
    if (isEditMode) {
      _initializeEditMode();
    }
  }

  void _initializeEditMode() {
    final init = widget.initialPurchase!;
    editPurchaseId = init['purchase_id']?.toString();
    selectedSupplierId = init['supplier_id']?.toString();
    _invoiceController.text = init['invoice_number']?.toString() ?? '';
    
    if (init['purchase_date'] != null) {
      purchaseDate = DateTime.tryParse(init['purchase_date'].toString());
    }
    if (init['due_date'] != null) {
      dueDate = DateTime.tryParse(init['due_date'].toString());
    }

    final items = init['items'] as List<dynamic>? ?? [];
    cart = items.map((item) {
      return {
        'product_id': item['product_id'],
        'name': item['products']?['name'] ?? 'Desconocido',
        'sku': item['products']?['sku'] ?? '',
        'quantity': item['quantity'],
        'unit_cost': (item['unit_cost'] as num).toDouble(),
        'previous_cost': (item['products']?['cost_usd'] as num?)?.toDouble() ?? 0.0,
        'is_exempt': item['is_exempt'] ?? false,
      };
    }).toList();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _freightController.dispose();
    _exchangeRateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final supRes = await supabase.from('suppliers').select().order('name');
      final prodRes = await supabase.from('products').select().eq('is_active', true).order('name');

      if (!mounted) return;

      setState(() {
        suppliers = List<Map<String, dynamic>>.from(supRes);
        products = List<Map<String, dynamic>>.from(prodRes);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando datos: ${e.toString()}', isError: true);
    }
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

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        searchResults = [];
      } else {
        final lowerQuery = query.toLowerCase();
        searchResults = products.where((p) {
          final nameMatch = (p['name']?.toString().toLowerCase() ?? '').contains(lowerQuery);
          final barcodeMatch = (p['barcode']?.toString().toLowerCase() ?? '').contains(lowerQuery);
          final skuMatch = (p['sku']?.toString().toLowerCase() ?? '').contains(lowerQuery);
          return nameMatch || barcodeMatch || skuMatch;
        }).take(10).toList();
      }
    });
  }

  Future<void> _showAddProductModal(Map<String, dynamic> product) async {
    int quantity = 1;
    bool isBox = false;
    bool isExempt = false;
    final int unitsPerBox = (product['units_per_box'] as num?)?.toInt() ?? 1;
    final double previousCost = (product['cost_usd'] as num?)?.toDouble() ?? 0.0;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int totalUnits = isBox ? quantity * unitsPerBox : quantity;
            return AlertDialog(
              title: Text('Agregar ${product['name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(child: Text('Comprar por: ')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<bool>(
                            isExpanded: true,
                            value: isBox,
                            items: const [
                              DropdownMenuItem(value: false, child: Text('Unidad')),
                              DropdownMenuItem(value: true, child: Text('Caja')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => isBox = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Text('Exento de IVA: ')),
                        Switch(
                          value: isExempt,
                          activeTrackColor: const Color(0xFF1E1336).withValues(alpha: 0.5),
                          activeThumbColor: const Color(0xFF1E1336),
                          onChanged: (val) {
                            setModalState(() => isExempt = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: quantity.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                      onChanged: (val) {
                        setModalState(() {
                          quantity = int.tryParse(val) ?? 1;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isBox)
                      Text(
                        '$quantity Cajas = $totalUnits Unidades totales',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addProductToCartWithQty(product, totalUnits, previousCost, isExempt);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                  child: const Text('Agregar al Carrito'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addProductToCartWithQty(Map<String, dynamic> product, int quantity, double previousCost, bool isExempt) {
    final existingIndex = cart.indexWhere((item) => item['product_id'] == product['id']);
    if (existingIndex >= 0) {
      setState(() {
        cart[existingIndex]['quantity'] += quantity;
      });
    } else {
      setState(() {
        cart.add({
          'product_id': product['id'],
          'name': product['name'],
          'sku': product['sku'],
          'quantity': quantity,
          'unit_cost': previousCost,
          'previous_cost': previousCost,
          'is_exempt': isExempt,
        });
      });
    }
    _searchController.clear();
    setState(() {
      searchResults = [];
    });
  }

  double get _subtotalBase {
    return cart.where((item) => !(item['is_exempt'] as bool? ?? false)).fold(0.0, (sum, item) {
      return sum + ((item['quantity'] as num).toInt() * (item['unit_cost'] as num).toDouble());
    });
  }

  double get _exemptAmount {
    return cart.where((item) => (item['is_exempt'] as bool? ?? false)).fold(0.0, (sum, item) {
      return sum + ((item['quantity'] as num).toInt() * (item['unit_cost'] as num).toDouble());
    });
  }

  double get _taxAmount => _subtotalBase * 0.16;

  double get _merchandiseTotal => _subtotalBase + _exemptAmount;

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final initialDate = isPurchaseDate ? (purchaseDate ?? DateTime.now()) : (dueDate ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          purchaseDate = picked;
        } else {
          dueDate = picked;
        }
      });
    }
  }

  Future<void> _processPurchase() async {
    if (selectedSupplierId == null) {
      _showSnackBar('Seleccione un proveedor', isError: true);
      return;
    }
    if (_invoiceController.text.trim().isEmpty) {
      _showSnackBar('Ingrese el número de factura', isError: true);
      return;
    }
    if (cart.isEmpty) {
      _showSnackBar('Agregue productos a la factura', isError: true);
      return;
    }
    if (dueDate == null) {
      _showSnackBar('Seleccione una fecha de vencimiento', isError: true);
      return;
    }

    setState(() => isProcessing = true);

    try {
      final items = cart.map((item) {
        return {
          'product_id': item['product_id'],
          'quantity': (item['quantity'] as num).toInt(),
          'unit_cost': (item['unit_cost'] as num).toDouble(),
          'is_exempt': item['is_exempt'] ?? false,
        };
      }).toList();

      final params = {
        'p_supplier_id': selectedSupplierId,
        'p_invoice_number': _invoiceController.text.trim(),
        'p_due_date': dueDate!.toIso8601String(),
        'p_merchandise_total': _merchandiseTotal,
        'p_subtotal_base': _subtotalBase,
        'p_exempt_amount': _exemptAmount,
        'p_tax_amount': _taxAmount,
        'p_freight_cost': freightCost,
        'p_exchange_rate': exchangeRate,
      };

      if (isEditMode) {
        params['p_purchase_id'] = editPurchaseId;
        params['p_new_items'] = items;
        await supabase.rpc('edit_purchase_transaction', params: params);

        _showSnackBar('Compra editada exitosamente');
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        params['p_items'] = items;
        await supabase.rpc('process_purchase_transaction', params: params);

        _showSnackBar('Compra procesada exitosamente');
        setState(() {
          cart.clear();
          _invoiceController.clear();
          _freightController.text = '0.00';
          _exchangeRateController.text = '1.00';
          freightCost = 0.0;
          exchangeRate = 1.0;
          selectedSupplierId = null;
          purchaseDate = DateTime.now();
          dueDate = DateTime.now().add(const Duration(days: 30));
        });
      }
    } catch (e) {
      _showSnackBar('Error al procesar la compra: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF281E59)),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    final Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalles de Factura',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1336),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Proveedor',
                          border: OutlineInputBorder(),
                        ),
                        items: suppliers.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'].toString(),
                            child: Text(s['name'] ?? 'Desconocido', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => selectedSupplierId = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _invoiceController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Factura',
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
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha de Compra',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            purchaseDate != null ? dateFormat.format(purchaseDate!) : '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Vencimiento',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            dueDate != null ? dateFormat.format(dueDate!) : '',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (searchResults.isNotEmpty)
          Card(
            elevation: 4,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final p = searchResults[index];
                return ListTile(
                  title: Text(p['name'] ?? ''),
                  subtitle: Text('SKU: ${p['sku']} | Costo: \$${((p['cost_usd'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                  trailing: const Icon(Icons.add_circle, color: Colors.green),
                  onTap: () => _showAddProductModal(p),
                );
              },
            ),
          ),
      ],
    );

    final Widget rightColumn = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos en Factura',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1336),
              ),
            ),
            const Divider(),
            cart.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('No hay productos agregados')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final totalItem = (item['quantity'] as num).toInt() * (item['unit_cost'] as num).toDouble();
                      
                      return Card(
                        color: Colors.grey.shade50,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 500;
                              if (isMobile) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => setState(() => cart.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            initialValue: item['quantity'].toString(),
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'Cant.', isDense: true, border: OutlineInputBorder()),
                                            onChanged: (val) {
                                              final qty = int.tryParse(val) ?? 0;
                                              setState(() => cart[index]['quantity'] = qty);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final previousCost = (item['previous_cost'] as num?)?.toDouble() ?? 0.0;
                                              final currentCost = (item['unit_cost'] as num).toDouble();
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  TextFormField(
                                                    initialValue: currentCost.toString(),
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: const InputDecoration(labelText: 'Costo \$', isDense: true, border: OutlineInputBorder()),
                                                    onChanged: (val) {
                                                      final cost = double.tryParse(val) ?? 0.0;
                                                      setState(() => cart[index]['unit_cost'] = cost);
                                                    },
                                                  ),
                                                  if (previousCost > 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0),
                                                      child: Text('Ant: \$${previousCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Exento: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            Checkbox(
                                              value: item['is_exempt'] as bool? ?? false,
                                              onChanged: (val) => setState(() => cart[index]['is_exempt'] = val ?? false),
                                            ),
                                          ],
                                        ),
                                        Text('Subtotal: \$${totalItem.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: item['quantity'].toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                                      onChanged: (val) {
                                        final qty = int.tryParse(val) ?? 0;
                                        setState(() => cart[index]['quantity'] = qty);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: Builder(
                                      builder: (context) {
                                        final previousCost = (item['previous_cost'] as num?)?.toDouble() ?? 0.0;
                                        final currentCost = (item['unit_cost'] as num).toDouble();
                                        final increase = currentCost > previousCost && previousCost > 0
                                            ? ((currentCost - previousCost) / previousCost) * 100
                                            : 0.0;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextFormField(
                                              initialValue: currentCost.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(labelText: 'Costo \$', isDense: true),
                                              onChanged: (val) {
                                                final cost = double.tryParse(val) ?? 0.0;
                                                setState(() => cart[index]['unit_cost'] = cost);
                                              },
                                            ),
                                            if (previousCost > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text('Ant: \$${previousCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ),
                                            if (increase > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text('+${increase.toStringAsFixed(1)}% vs ant.', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        );
                                      }
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      children: [
                                        const Text('Exento', style: TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                        SizedBox(
                                          height: 24,
                                          child: Checkbox(
                                            value: item['is_exempt'] as bool? ?? false,
                                            onChanged: (val) => setState(() => cart[index]['is_exempt'] = val ?? false),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: Text('\$${totalItem.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(() => cart.removeAt(index)),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Subtotal Base:', style: TextStyle(fontSize: 14))),
                Text('\$${_subtotalBase.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('Exento:', style: TextStyle(fontSize: 14))),
                Text('\$${_exemptAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('IVA (16%):', style: TextStyle(fontSize: 14))),
                Text('\$${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _freightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Flete/Gastos (USD)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => freightCost = double.tryParse(val) ?? 0.0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _exchangeRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tasa (Bs)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => exchangeRate = double.tryParse(val) ?? 1.0),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL GENERAL:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '\$${(_merchandiseTotal + _taxAmount + freightCost).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF281E59)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isProcessing ? null : _processPurchase,
                child: isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Procesar Compra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: (context.isMobile && !isEditMode)
          ? null
          : AppBar(
              title: Text(isEditMode ? 'Editar Compra' : 'Módulo de Compras', style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1E1336),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: isEditMode,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 800;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: leftColumn),
                      const SizedBox(width: 24),
                      Expanded(flex: 5, child: rightColumn),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftColumn,
                      const SizedBox(height: 24),
                      rightColumn,
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
