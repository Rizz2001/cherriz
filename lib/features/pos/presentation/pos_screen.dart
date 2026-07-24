import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../utils/receipt_generator.dart';
import '../utils/cash_report_pdf_generator.dart';
import '../../../core/utils/responsive_layout.dart';

import 'package:flutter/services.dart';

class SearchIntent extends Intent { const SearchIntent(); }
class CheckoutIntent extends Intent { const CheckoutIntent(); }
class ClearCartIntent extends Intent { const ClearCartIntent(); }
class CashRegisterIntent extends Intent { const CashRegisterIntent(); }
class ConfirmCheckoutIntent extends Intent { const ConfirmCheckoutIntent(); }

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final supabase = Supabase.instance.client;

  bool isSessionOpen = false;
  Map<String, dynamic>? currentSession;
  Map<String, dynamic>? currentCompany;
  final TextEditingController _usdController = TextEditingController(text: '0.00');
  final TextEditingController _bsController = TextEditingController(text: '0.00');

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = true;
  double exchangeRate = 40.00;

  // Estado del Carrito y Cliente
  List<Map<String, dynamic>> cartItems = [];
  Map<String, dynamic>? selectedCustomer;
  bool isCreditSale = false;
  List<Map<String, dynamic>> customersList = [];

  // Shortcuts
  final FocusNode _searchFocusNode = FocusNode();

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

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _usdController.dispose();
    _bsController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);

    try {
      // 1. Obtener Tasa de Cambio Global y Empresa
      final compRes = await supabase.from('companies').select().limit(1);
      if (compRes.isNotEmpty) {
        currentCompany = compRes.first;
        final rate = (compRes.first['exchange_rate'] as num?)?.toDouble();
        if (rate != null) exchangeRate = rate;
      }

      // 1.5 Verificar Sesión de Caja
      final sessionRes = await supabase
          .from('cash_sessions')
          .select()
          .isFilter('closed_at', null)
          .order('created_at', ascending: false)
          .limit(1);

      if (sessionRes.isNotEmpty) {
        isSessionOpen = true;
        currentSession = sessionRes.first;
      } else {
        isSessionOpen = false;
        currentSession = null;
      }

      // 2. Obtener Productos
      final response = await supabase
          .from('products')
          .select()
          .eq('is_active', true);

      // 3. Obtener Clientes
      final customersRes = await supabase
          .from('customers')
          .select()
          .order('name');

      if (!mounted) return;
      setState(() {
        products = List<Map<String, dynamic>>.from(response);
        filteredProducts = List<Map<String, dynamic>>.from(response);
        customersList = List<Map<String, dynamic>>.from(customersRes);
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

  Future<void> _openSession() async {
    final usd = double.tryParse(_usdController.text) ?? 0.0;
    final bs = double.tryParse(_bsController.text) ?? 0.0;
    
    try {
      final res = await supabase.from('cash_sessions').insert({
        'opening_balance_usd': usd,
        'opening_balance_bs': bs,
      }).select().single();
      
      if (!mounted) return;
      setState(() {
        isSessionOpen = true;
        currentSession = res;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caja abierta exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error abriendo caja: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  Future<void> _closeSession() async {
    if (currentSession == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar Caja?'),
        content: const Text('Se registrará el cierre de caja y se generará el reporte Corte Z.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Caja'),
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final sessionId = currentSession!['id'].toString();

      await supabase.from('cash_sessions').update({
        'closed_at': DateTime.now().toIso8601String(),
        'status': 'CERRADA',
      }).eq('id', sessionId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caja cerrada. Generando reporte...')));

      // Generar Reporte PDF
      await generateCashReportPdf(
        sessionId: sessionId,
        company: currentCompany ?? {'name': 'Mi Empresa'},
        sessionData: currentSession!,
      );

      if (!mounted) return;
      setState(() {
        isSessionOpen = false;
        currentSession = null;
        cartItems.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cerrando caja: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
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

  Future<void> _showCheckoutModal(String sessionId) async {
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

            Future<void> Function()? onConfirm;

            return Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.escape): const ClearCartIntent(),
                LogicalKeySet(LogicalKeyboardKey.enter): const ConfirmCheckoutIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ClearCartIntent: CallbackAction<ClearCartIntent>(
                    onInvoke: (ClearCartIntent intent) {
                      Navigator.of(dialogContext).pop();
                      return null;
                    },
                  ),
                  ConfirmCheckoutIntent: CallbackAction<ConfirmCheckoutIntent>(
                    onInvoke: (ConfirmCheckoutIntent intent) {
                      onConfirm?.call();
                      return null;
                    },
                  ),
                },
                child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: context.isMobile ? MediaQuery.of(context).size.width * 0.95 : 700,
                ),
                padding: EdgeInsets.all(context.isMobile ? 16.0 : 32.0),
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
                            'Confirmar Pago',
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
                      const SizedBox(height: 16),
                      // Selector Contado / Crédito
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'CONTADO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: isCreditSale,
                            activeTrackColor: Colors.orange.shade200,
                            activeThumbColor: Colors.orange.shade800,
                            inactiveTrackColor: Colors.green.shade200,
                            inactiveThumbColor: Colors.green.shade800,
                            onChanged: (val) {
                              setModalState(() {});
                              setState(() {
                                isCreditSale = val;
                                if (!val) selectedCustomer = null;
                              });
                            },
                          ),
                          const Text(
                            'CRÉDITO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (isCreditSale) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: selectedCustomer,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Cliente Obligatorio',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: customersList
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    '${c['name']} (${c['document_id']})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setModalState(() {});
                            setState(() {
                              selectedCustomer = val;
                            });
                          },
                        ),
                      ],
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
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '\$${_cartTotalUsd.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF281E59),
                                      ),
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
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '\$${(remainingUsd > 0 ? remainingUsd : 0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: remainingUsd <= 0
                                            ? Colors.green.shade700
                                            : Colors.redAccent,
                                      ),
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
                      if (!isCreditSale) const SizedBox(height: 32),

                      // Formulario de Pago (Solo si es Contado)
                      if (!isCreditSale)
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
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: currentMethod,
                                      isExpanded: true,
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
                                ],
                              ),
                              if (currentMethod == 'Pago Móvil' ||
                                  currentMethod == 'Zelle') ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: refController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Referencia (4 dígitos)',
                                    border: OutlineInputBorder(),
                                    counterText: '',
                                  ),
                                ),
                              ],
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                      if (!isCreditSale) const SizedBox(height: 24),

                      // Lista de Pagos
                      if (!isCreditSale && payments.isNotEmpty)
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
                          onPressed: onConfirm =
                              ((!canProcess && !isCreditSale) ||
                                  (isCreditSale && selectedCustomer == null) ||
                                  isProcessingSale)
                              ? null
                              : () async {
                                  setModalState(() => isProcessingSale = true);

                                  try {
                                    final companyId = cartItems
                                        .first['product']['company_id'];

                                    // Procesar venta atómicamente con RPC
                                    final List<Map<String, dynamic>> rpcItems =
                                        cartItems.map((item) {
                                          final product = item['product'];
                                          final qty =
                                              (item['quantity'] as num?)
                                                  ?.toInt() ??
                                              1;
                                          final priceUsd =
                                              (product['price_usd'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          return {
                                            'product_id': product['id'],
                                            'quantity': qty,
                                            'unit_price_usd': priceUsd,
                                          };
                                        }).toList();

                                    final List<Map<String, dynamic>>
                                    rpcPayments = isCreditSale
                                        ? []
                                        : payments.map((p) {
                                            final amt =
                                                (p['amount'] as num?)
                                                    ?.toDouble() ??
                                                0.0;
                                            final method =
                                                p['method'] as String;
                                            final isUsd =
                                                method.contains('USD') ||
                                                method == 'Zelle';
                                            return {
                                              'payment_method': method,
                                              'amount_paid': amt,
                                              'currency': isUsd ? 'USD' : 'BS',
                                              'exchange_rate': exchangeRate,
                                            };
                                          }).toList();

                                    final response = await supabase.rpc(
                                      'process_sale_transaction',
                                      params: {
                                        'p_session_id': sessionId,
                                        'p_customer_id':
                                            selectedCustomer?['id'],
                                        'p_sale_type': isCreditSale
                                            ? 'CREDITO'
                                            : 'CONTADO',
                                        'p_total_amount_usd': _cartTotalUsd,
                                        'p_exchange_rate': exchangeRate,
                                        'p_items': rpcItems,
                                        'p_payments': rpcPayments,
                                      },
                                    );
                                    
                                    final generatedInvoiceNumber = (response as Map<String, dynamic>)['invoice_number']?.toString() ?? '0000000';

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
                                    final finalCustomer = selectedCustomer;
                                    final finalIsCredit = isCreditSale;

                                    if (!dialogContext.mounted) return;
                                    Navigator.of(dialogContext).pop();

                                    if (!mounted || !context.mounted) return;
                                    setState(() {
                                      cartItems.clear();
                                      selectedCustomer = null;
                                      isCreditSale = false;
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
                                      customer: finalCustomer,
                                      isCreditSale: finalIsCredit,
                                      invoiceNumber: generatedInvoiceNumber,
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
            )));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): const CheckoutIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space): const CheckoutIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const ClearCartIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (SearchIntent intent) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          CheckoutIntent: CallbackAction<CheckoutIntent>(
            onInvoke: (CheckoutIntent intent) async {
              if (cartItems.isNotEmpty) {
                try {
                  final sessionRes = await supabase
                      .from('cash_sessions')
                      .select('id')
                      .isFilter('closed_at', null)
                      .order('created_at', ascending: false)
                      .limit(1);

                  if (sessionRes.isEmpty) {
                    if (!mounted || !context.mounted) return null;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debe abrir caja en el módulo de Caja antes de facturar'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return null;
                  }
                  final sessionId = sessionRes.first['id'].toString();
                  _showCheckoutModal(sessionId);
                } catch (e) {
                  if (!mounted || !context.mounted) return null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error validando sesión: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
              return null;
            },
          ),
          ClearCartIntent: CallbackAction<ClearCartIntent>(
            onInvoke: (ClearCartIntent intent) {
              if (cartItems.isNotEmpty) {
                setState(() => cartItems.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carrito limpiado')),
                );
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Gran Catador',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          if (isSessionOpen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
                label: const Text('Cerrar Caja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _closeSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isSessionOpen
              ? _buildOpenSessionForm()
              : ResponsiveBuilder(
                  mobile: _buildMobilePosLayout(context),
                  tablet: _buildDesktopOrTabletPosLayout(context, isTablet: true),
                  desktop: _buildDesktopOrTabletPosLayout(context, isTablet: false),
                ),
        ),
      ),
    );
  }

  Widget _buildDesktopOrTabletPosLayout(BuildContext context, {required bool isTablet}) {
    return Row(
      children: [
        // PANEL PRINCIPAL (Productos y Búsqueda)
        Expanded(
          flex: isTablet ? 6 : 7,
          child: _buildCatalogPanel(context),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // PANEL DEL CARRITO (Orden Actual y Totales)
        Expanded(
          flex: isTablet ? 4 : 3,
          child: _buildCartPanel(context),
        ),
      ],
    );
  }

  Widget _buildMobilePosLayout(BuildContext context) {
    final int totalCartQty = cartItems.fold(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
    );

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1E1336),
            child: TabBar(
              indicatorColor: const Color(0xFF7E57C2),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                const Tab(icon: Icon(Icons.grid_view_rounded), text: 'Catálogo'),
                Tab(
                  icon: Badge(
                    label: Text('$totalCartQty'),
                    isLabelVisible: totalCartQty > 0,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  text: 'Orden Actual',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCatalogPanel(context),
                _buildCartPanel(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.isMobile ? 12.0 : 20.0),
      child: Column(
        children: [
          TextField(
            focusNode: _searchFocusNode,
            onChanged: _filterProducts,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
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
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.responsiveValue(
                            mobile: 2,
                            tablet: 3,
                            desktop: 4,
                          ),
                          childAspectRatio: context.responsiveValue(
                            mobile: 0.78,
                            tablet: 0.85,
                            desktop: 0.85,
                          ),
                          crossAxisSpacing: context.responsiveValue(
                            mobile: 10.0,
                            tablet: 16.0,
                            desktop: 16.0,
                          ),
                          mainAxisSpacing: context.responsiveValue(
                            mobile: 10.0,
                            tablet: 16.0,
                            desktop: 16.0,
                          ),
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(filteredProducts[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF281E59)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente: ${selectedCustomer?['name'] ?? 'Consumidor Final'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'C.I/RIF: ${selectedCustomer?['document_id'] ?? 'V-00000000'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCreditSale
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCreditSale ? 'CRÉDITO' : 'CONTADO',
                    style: TextStyle(
                      color: isCreditSale
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                      final priceUsd = (product['price_usd'] as num?)?.toDouble() ?? 0.0;
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
                                    onPressed: () => _decrementQty(index),
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
                                    onPressed: () => _incrementQty(index),
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
                              crossAxisAlignment: CrossAxisAlignment.end,
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
                        : () async {
                            try {
                              final sessionRes = await supabase
                                  .from('cash_sessions')
                                  .select('id')
                                  .isFilter('closed_at', null)
                                  .order('created_at', ascending: false)
                                  .limit(1);

                              if (sessionRes.isEmpty) {
                                if (!mounted || !context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Debe abrir caja en el módulo de Caja antes de facturar',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              final sessionId = sessionRes.first['id'].toString();
                              _showCheckoutModal(sessionId);
                            } catch (e) {
                              if (!mounted || !context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error validando sesión: $e',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
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
    Map<String, dynamic>? customer,
    bool isCreditSale = false,
    required String invoiceNumber,
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
                      customer: customer,
                      isCreditSale: isCreditSale,
                      invoiceNumber: invoiceNumber,
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
                      customer: customer,
                      isCreditSale: isCreditSale,
                      invoiceNumber: invoiceNumber,
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

  Widget _buildOpenSessionForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: context.isMobile ? MediaQuery.of(context).size.width * 0.9 : 400,
            ),
            padding: EdgeInsets.all(context.isMobile ? 20 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale, size: 64, color: Color(0xFF1E1336)),
              const SizedBox(height: 16),
              const Text('Abrir Caja', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1336))),
              const SizedBox(height: 24),
              TextField(
                controller: _usdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fondo Inicial (USD)', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fondo Inicial (Bs)', prefixText: 'Bs ', prefixIcon: Icon(Icons.money), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                  onPressed: _openSession,
                  child: const Text('Confirmar Apertura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
