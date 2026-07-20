import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../utils/receipt_generator.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = true;
  double exchangeRate = 40.00;

  // Estado del Carrito
  List<Map<String, dynamic>> cartItems = [];

  // Calcular el total derivado del estado
  double get _cartTotalUsd => cartItems.fold(0, (sum, item) {
    final price = (item['product']['price_usd'] as num?)?.toDouble() ?? 0.0;
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    return sum + (price * qty);
  });

  double get _cartTotalBs => _cartTotalUsd * exchangeRate;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);

    try {
      // 1. Obtener Tasa de Cambio Global
      final compRes = await supabase.from('companies').select().limit(1);
      if (compRes.isNotEmpty) {
        final rate = (compRes.first['exchange_rate'] as num?)?.toDouble();
        if (rate != null) exchangeRate = rate;
      }

      // 2. Obtener Productos
      final response = await supabase
          .from('products')
          .select()
          .eq('is_active', true);

      if (!mounted) return;
      setState(() {
        products = List<Map<String, dynamic>>.from(response);
        filteredProducts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al cargar datos iniciales: $e',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF1E1336).withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      );
    }
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredProducts = List.from(products);
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        final name = (product['name']?.toString() ?? '').toLowerCase();
        final category = (product['category']?.toString() ?? '').toLowerCase();
        return name.contains(lowerQuery) || category.contains(lowerQuery);
      }).toList();
    });
  }

  // --- Lógica del Carrito ---

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final index = cartItems.indexWhere(
        (item) => item['product']['id'] == product['id'],
      );
      if (index != -1) {
        cartItems[index]['quantity']++;
      } else {
        cartItems.add({'product': product, 'quantity': 1});
      }
    });
  }

  void _incrementQty(int index) {
    setState(() {
      cartItems[index]['quantity']++;
    });
  }

  void _decrementQty(int index) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        cartItems[index]['quantity']--;
      } else {
        cartItems.removeAt(index);
      }
    });
  }

  Future<void> _showCheckoutModal() async {
    List<Map<String, dynamic>> payments = [];
    String currentMethod = 'Efectivo USD';
    final amountController = TextEditingController();
    final refController = TextEditingController();

    final methods = [
      'Efectivo USD',
      'Efectivo Bs',
      'Pago Móvil',
      'Zelle',
      'Punto de Venta',
    ];
    bool isProcessingSale = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            // Cálculos dinámicos del pago
            double totalPaidEquivalentUsd = 0.0;
            for (var p in payments) {
              final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
              final method = p['method'] as String;
              if (method.contains('Bs') ||
                  method == 'Pago Móvil' ||
                  method == 'Punto de Venta') {
                totalPaidEquivalentUsd += (amt / exchangeRate);
              } else {
                totalPaidEquivalentUsd += amt; // USD methods
              }
            }

            final changeUsd = totalPaidEquivalentUsd > _cartTotalUsd
                ? totalPaidEquivalentUsd - _cartTotalUsd
                : 0.0;
            final changeBs = changeUsd * exchangeRate;
            final remainingUsd = totalPaidEquivalentUsd >= _cartTotalUsd
                ? 0.0
                : _cartTotalUsd - totalPaidEquivalentUsd;
            final remainingBs = remainingUsd * exchangeRate;

            // El botón de Procesar se habilita si no queda deuda (con margen de 0.001 por redondeo)
            final canProcess =
                totalPaidEquivalentUsd >= (_cartTotalUsd - 0.001);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: 700,
                padding: const EdgeInsets.all(32.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          const Text(
                            'Confirmar Pago (Multipago)',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1336),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Resumen de Totales
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Total a Pagar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${_cartTotalUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF281E59),
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${_cartTotalBs.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: remainingUsd <= 0
                                    ? Colors.green.shade50
                                    : const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Resta por Pagar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${(remainingUsd > 0 ? remainingUsd : 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: remainingUsd <= 0
                                          ? Colors.green.shade700
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${(remainingBs > 0 ? remainingBs : 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: remainingUsd <= 0
                                          ? Colors.green.shade700
                                          : Colors.redAccent.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (changeUsd > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Vuelto a Entregar:',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${changeUsd.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Bs. ${changeBs.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Formulario de Pago
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Añadir Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: currentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Método',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: methods
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(
                                          () => currentMethod = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Monto',
                                      border: const OutlineInputBorder(),
                                      prefixText:
                                          (currentMethod.contains('USD') ||
                                              currentMethod == 'Zelle')
                                          ? '\$ '
                                          : 'Bs. ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (currentMethod == 'Pago Móvil' ||
                                    currentMethod == 'Zelle')
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: refController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 4,
                                      decoration: const InputDecoration(
                                        labelText: 'Referencia (4 dígitos)',
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir Pago'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF281E59),
                                  side: const BorderSide(
                                    color: Color(0xFF281E59),
                                  ),
                                ),
                                onPressed: () {
                                  final amt = double.tryParse(
                                    amountController.text,
                                  );
                                  if (amt == null || amt <= 0) return;

                                  if ((currentMethod == 'Pago Móvil' ||
                                          currentMethod == 'Zelle') &&
                                      refController.text.length < 4) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ingrese 4 dígitos de referencia',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    payments.add({
                                      'method': currentMethod,
                                      'amount': amt,
                                      'ref_digits': refController.text.trim(),
                                    });
                                    amountController.clear();
                                    refController.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Lista de Pagos
                      if (payments.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: payments.length,
                            itemBuilder: (context, idx) {
                              final p = payments[idx];
                              final prefix =
                                  (p['method'].toString().contains('USD') ||
                                      p['method'] == 'Zelle')
                                  ? '\$'
                                  : 'Bs.';
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.payments_outlined,
                                  color: Color(0xFF281E59),
                                ),
                                title: Text(
                                  '${p['method']} - $prefix${((p['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: p['ref_digits'].toString().isNotEmpty
                                    ? Text('Ref: ${p['ref_digits']}')
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => setModalState(
                                    () => payments.removeAt(idx),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Acción Final
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1336),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          onPressed: (!canProcess || isProcessingSale)
                              ? null
                              : () async {
                                  setModalState(() => isProcessingSale = true);

                                  try {
                                    final companyId = cartItems
                                        .first['product']['company_id'];

                                    // 1. Inserción de la Orden
                                    final orderResponse = await supabase
                                        .from('orders')
                                        .insert({
                                          'company_id': companyId,
                                          'total_usd': _cartTotalUsd,
                                          'total_bs': _cartTotalBs,
                                        })
                                        .select()
                                        .single();

                                    final orderId = orderResponse['id'];

                                    // 2. Inserción de Detalles (Items)
                                    final List<Map<String, dynamic>>
                                    orderItems = cartItems.map((item) {
                                      final product = item['product'];
                                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                                      final priceUsd =
                                          (product['price_usd'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                      return {
                                        'order_id': orderId,
                                        'product_id': product['id'],
                                        'quantity': qty,
                                        'price_usd': priceUsd,
                                        'subtotal_usd': priceUsd * qty,
                                      };
                                    }).toList();

                                    await supabase
                                        .from('order_items')
                                        .insert(orderItems);

                                    // 3. Inserción de Pagos
                                    final List<Map<String, dynamic>>
                                    orderPayments = payments.map((p) {
                                      final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
                                      final method = p['method'] as String;

                                      // Calcular equivalentes (USD y Bs) para mantener ambas columnas requeridas
                                      double amountUsd = 0;
                                      double amountBs = 0;

                                      if (method.contains('Bs') ||
                                          method == 'Pago Móvil' ||
                                          method == 'Punto de Venta') {
                                        amountBs = amt;
                                        amountUsd = amt / exchangeRate;
                                      } else {
                                        amountUsd = amt;
                                        amountBs = amt * exchangeRate;
                                      }

                                      return {
                                        'order_id': orderId,
                                        'payment_method': method,
                                        'amount_usd': amountUsd,
                                        'amount_bs': amountBs,
                                        'ref_digits':
                                            p['ref_digits']
                                                    ?.toString()
                                                    .isEmpty ??
                                                true
                                            ? null
                                            : p['ref_digits'],
                                      };
                                    }).toList();

                                    await supabase
                                        .from('order_payments')
                                        .insert(orderPayments);

                                    // 4. Éxito
                                    final companyData = await supabase
                                        .from('companies')
                                        .select()
                                        .eq('id', companyId)
                                        .single();

                                    final clonedCart =
                                        List<Map<String, dynamic>>.from(
                                          cartItems,
                                        );
                                    final clonedPayments =
                                        List<Map<String, dynamic>>.from(
                                          payments,
                                        );
                                    final finalTotalUsd = _cartTotalUsd;
                                    final finalTotalBs = _cartTotalBs;
                                    final finalChangeUsd = changeUsd;
                                    final finalChangeBs = changeBs;

                                    if (!dialogContext.mounted) return;
                                    Navigator.of(dialogContext).pop();

                                    if (!mounted) return;
                                    setState(() {
                                      cartItems.clear();
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Venta procesada exitosamente',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.green.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                      ),
                                    );

                                    _showReceiptDialog(
                                      company: companyData,
                                      cartItems: clonedCart,
                                      payments: clonedPayments,
                                      totalUsd: finalTotalUsd,
                                      totalBs: finalTotalBs,
                                      changeUsd: finalChangeUsd,
                                      changeBs: finalChangeBs,
                                    );
                                  } catch (e) {
                                    // 5. Error
                                    setModalState(
                                      () => isProcessingSale = false,
                                    );

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error procesando la venta: $e',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: isProcessingSale
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Procesar Venta',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Cherriz POS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar Catálogo',
            onPressed: _fetchInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Panel Administrativo',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // PANEL PRINCIPAL (Productos y Búsqueda) - FLEX 7
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    onChanged: _filterProducts,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar producto por nombre o código de barras...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF281E59),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF281E59),
                            ),
                          )
                        : filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron productos',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(filteredProducts[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // PANEL DEL CARRITO (Orden Actual y Totales) - FLEX 3
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          color: Color(0xFF281E59),
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Orden Actual',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1336),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: cartItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 72,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay productos en la orden',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: cartItems.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              final product = item['product'];
                              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                              final priceUsd =
                                  (product['price_usd'] as num?)?.toDouble() ??
                                  0.0;
                              final subtotalUsd = priceUsd * qty;
                              final subtotalBs = subtotalUsd * exchangeRate;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F6F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 20,
                                              color: Colors.black54,
                                            ),
                                            onPressed: () =>
                                                _decrementQty(index),
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                          ),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 20,
                                              color: Colors.black54,
                                            ),
                                            onPressed: () =>
                                                _incrementQty(index),
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        product['name'] ?? 'Producto',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${subtotalUsd.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF281E59),
                                          ),
                                        ),
                                        Text(
                                          'Bs. ${subtotalBs.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          offset: const Offset(0, -6),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total USD',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1336),
                              ),
                            ),
                            Text(
                              '\$${_cartTotalUsd.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF281E59),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Bs.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Bs. ${_cartTotalBs.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1336),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: cartItems.isEmpty
                                ? null
                                : _showCheckoutModal,
                            child: const Text(
                              'COBRAR',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Sin nombre';
    final category = product['category'] ?? 'Sin categoría';
    final unitType = product['unit_type'] ?? 'Unidad';
    final priceUsd = (product['price_usd'] as num?)?.toDouble() ?? 0.0;
    final priceBs = priceUsd * exchangeRate;

    const iconColor = Color(0xFF281E59);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: Colors.black26,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: iconColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            unitType,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${priceUsd.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF281E59),
                            ),
                          ),
                          Text(
                            'Bs. ${priceBs.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptDialog({
    required Map<String, dynamic> company,
    required List<Map<String, dynamic>> cartItems,
    required List<Map<String, dynamic>> payments,
    required double totalUsd,
    required double totalBs,
    required double changeUsd,
    required double changeBs,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Recibo Generado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1336),
            ),
          ),
          content: const Text(
            '¿Desea Imprimir o Compartir el recibo de esta venta?',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final pdfBytes = await generateReceipt(
                      company: company,
                      cartItems: cartItems,
                      payments: payments,
                      totalUsd: totalUsd,
                      totalBs: totalBs,
                      exchangeRate: exchangeRate,
                      changeUsd: changeUsd,
                      changeBs: changeBs,
                    );
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: 'recibo_cherriz.pdf',
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Compartir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF281E59),
                    side: const BorderSide(color: Color(0xFF281E59)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final pdfBytes = await generateReceipt(
                      company: company,
                      cartItems: cartItems,
                      payments: payments,
                      totalUsd: totalUsd,
                      totalBs: totalBs,
                      exchangeRate: exchangeRate,
                      changeUsd: changeUsd,
                      changeBs: changeBs,
                    );
                    await Printing.layoutPdf(
                      onLayout: (format) => pdfBytes,
                      name: 'Recibo',
                    );
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1336),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
