import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PurchasesModuleScreen extends StatefulWidget {
  const PurchasesModuleScreen({super.key});

  @override
  State<PurchasesModuleScreen> createState() => _PurchasesModuleScreenState();
}

class _PurchasesModuleScreenState extends State<PurchasesModuleScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isProcessing = false;

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> searchResults = [];

  String? selectedSupplierId;
  final TextEditingController _invoiceController = TextEditingController();
  DateTime? purchaseDate = DateTime.now();
  DateTime? dueDate = DateTime.now().add(const Duration(days: 30));

  final TextEditingController _searchController = TextEditingController();

  // Cart items structure: { 'product_id', 'name', 'sku', 'quantity', 'unit_cost' }
  List<Map<String, dynamic>> cart = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
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
      _showSnackBar('Error cargando datos: $e', isError: true);
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

  void _addProductToCart(Map<String, dynamic> product) {
    final existingIndex = cart.indexWhere((item) => item['product_id'] == product['id']);
    if (existingIndex >= 0) {
      setState(() {
        cart[existingIndex]['quantity'] += 1;
      });
    } else {
      setState(() {
        cart.add({
          'product_id': product['id'],
          'name': product['name'],
          'sku': product['sku'],
          'quantity': 1,
          'unit_cost': (product['cost_usd'] as num?)?.toDouble() ?? 0.0,
        });
      });
    }
    _searchController.clear();
    setState(() {
      searchResults = [];
    });
  }

  double get _totalAmount {
    return cart.fold(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toInt();
      final cost = (item['unit_cost'] as num).toDouble();
      return sum + (qty * cost);
    });
  }

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
        };
      }).toList();

      await supabase.rpc('process_purchase_transaction', params: {
        'p_supplier_id': selectedSupplierId,
        'p_invoice_number': _invoiceController.text.trim(),
        'p_due_date': dueDate!.toIso8601String(),
        'p_total_amount': _totalAmount,
        'p_items': items,
      });

      _showSnackBar('Compra procesada exitosamente');
      setState(() {
        cart.clear();
        _invoiceController.clear();
        selectedSupplierId = null;
        purchaseDate = DateTime.now();
        dueDate = DateTime.now().add(const Duration(days: 30));
      });
    } catch (e) {
      _showSnackBar('Error al procesar la compra: $e', isError: true);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Módulo de Compras', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Invoice Details & Search
            Expanded(
              flex: 4,
              child: Column(
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
                                  initialValue: selectedSupplierId,
                                  decoration: const InputDecoration(
                                    labelText: 'Proveedor',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: suppliers.map((s) {
                                    return DropdownMenuItem<String>(
                                      value: s['id'].toString(),
                                      child: Text(s['name'] ?? 'Desconocido'),
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
                                    child: Text(purchaseDate != null ? dateFormat.format(purchaseDate!) : ''),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectDate(context, false),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Fecha de Vencimiento',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(dueDate != null ? dateFormat.format(dueDate!) : ''),
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
                      hintText: 'Buscar producto por nombre, SKU o código de barras...',
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
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final p = searchResults[index];
                          return ListTile(
                            title: Text(p['name'] ?? ''),
                            subtitle: Text('SKU: ${p['sku']} | Costo: \$${((p['cost_usd'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                            trailing: const Icon(Icons.add_circle, color: Colors.green),
                            onTap: () => _addProductToCart(p),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Cart & Processing
            Expanded(
              flex: 5,
              child: Card(
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
                      Expanded(
                        child: cart.isEmpty
                            ? const Center(child: Text('No hay productos agregados'))
                            : ListView.builder(
                                itemCount: cart.length,
                                itemBuilder: (context, index) {
                                  final item = cart[index];
                                  final totalItem = (item['quantity'] as num).toInt() * (item['unit_cost'] as num).toDouble();
                                  
                                  return Card(
                                    color: Colors.grey.shade50,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              initialValue: item['quantity'].toString(),
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Cant.',
                                                isDense: true,
                                              ),
                                              onChanged: (val) {
                                                final qty = int.tryParse(val) ?? 0;
                                                setState(() {
                                                  cart[index]['quantity'] = qty;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              initialValue: item['unit_cost'].toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Costo \$',
                                                isDense: true,
                                              ),
                                              onChanged: (val) {
                                                final cost = double.tryParse(val) ?? 0.0;
                                                setState(() {
                                                  cart[index]['unit_cost'] = cost;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 2,
                                            child: Text('\$${totalItem.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                cart.removeAt(index);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Factura:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF281E59),
                            ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
