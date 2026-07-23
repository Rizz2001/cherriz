import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/responsive_layout.dart';
import 'purchases_module_screen.dart';

class AccountsPayableScreen extends StatefulWidget {
  const AccountsPayableScreen({super.key});

  @override
  State<AccountsPayableScreen> createState() => _AccountsPayableScreenState();
}

class _AccountsPayableScreenState extends State<AccountsPayableScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> suppliers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    try {
      final res = await supabase.from('suppliers').select();
      if (!mounted) return;
      setState(() {
        suppliers = List<Map<String, dynamic>>.from(res);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando proveedores: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getSupplierName(String supplierId) {
    final supplier = suppliers.firstWhere(
      (s) => s['id'].toString() == supplierId,
      orElse: () => {'name': 'Desconocido'},
    );
    return supplier['name'] ?? 'Desconocido';
  }

  Future<void> _showPaymentModal(Map<String, dynamic> account) async {
    final totalDebt = (account['total_debt'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (account['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = totalDebt - amountPaid;

    final TextEditingController amountController = TextEditingController(text: pendingAmount.toStringAsFixed(2));
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Abonar a Cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Deuda Total: \$${totalDebt.toStringAsFixed(2)}'),
                  Text('Monto Pendiente: \$${pendingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto a Abonar \$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isProcessing ? null : () async {
                    final payment = double.tryParse(amountController.text) ?? 0.0;
                    if (payment <= 0 || payment > pendingAmount) {
                      _showSnackBar('Monto inválido. Debe ser mayor a 0 y menor o igual a \$${pendingAmount.toStringAsFixed(2)}', isError: true);
                      return;
                    }

                    setModalState(() => isProcessing = true);

                    final newAmountPaid = amountPaid + payment;
                    String newStatus = 'PARCIAL';
                    if (newAmountPaid >= totalDebt) {
                      newStatus = 'PAGADO';
                    }

                    try {
                      await supabase.from('accounts_payable').update({
                        'amount_paid': newAmountPaid,
                        'status': newStatus,
                      }).eq('id', account['id']);
                      
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _showSnackBar('Abono registrado exitosamente');
                    } catch (e) {
                      setModalState(() => isProcessing = false);
                      if (!context.mounted) return;
                      _showSnackBar('Error al procesar el pago: $e', isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                  child: isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Procesar Abono'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editInvoice(Map<String, dynamic> account) async {
    final purchaseId = account['purchase_id'];
    if (purchaseId == null) {
      _showSnackBar('No hay ID de compra asociado a esta cuenta', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final purchaseRes = await supabase.from('purchases').select().eq('id', purchaseId).single();
      final itemsRes = await supabase.from('purchase_items').select('*, products(name, sku, cost_usd)').eq('purchase_id', purchaseId);

      if (!mounted) return;

      final initialPurchase = {
        'purchase_id': purchaseId,
        'supplier_id': account['supplier_id'],
        'invoice_number': purchaseRes['invoice_number'],
        'purchase_date': purchaseRes['created_at'],
        'due_date': account['due_date'],
        'items': itemsRes,
      };

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchasesModuleScreen(initialPurchase: initialPurchase),
        ),
      );
    } catch (e) {
      _showSnackBar('Error al descargar detalles de la factura: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }

  Map<String, List<Map<String, dynamic>>> _groupAccountsByMonth(List<Map<String, dynamic>> accounts) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var acc in accounts) {
      final dueDateStr = acc['due_date']?.toString() ?? acc['created_at']?.toString();
      DateTime date = DateTime.now();
      if (dueDateStr != null) {
        date = DateTime.tryParse(dueDateStr) ?? date;
      }

      final monthKey = '${_getMonthName(date.month)} ${date.year}';
      
      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(acc);
    }
    return grouped;
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final supplierName = _getSupplierName(account['supplier_id'].toString());
    final totalDebt = (account['total_debt'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (account['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final status = account['status']?.toString() ?? 'PENDIENTE';
    final dueDateStr = account['due_date']?.toString();
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    Color statusColor = Colors.redAccent;
    if (status == 'PAGADO') statusColor = Colors.green;
    if (status == 'PARCIAL') statusColor = Colors.orange;

    final canEdit = amountPaid == 0 || status == 'PENDIENTE';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    supplierName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: () => _editInvoice(account),
                    tooltip: 'Editar Factura',
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Total: \$${totalDebt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            Text('Pagado: \$${amountPaid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (dueDate != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Vence: ${dateFormat.format(dueDate)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            const SizedBox(height: 8),
            if (status != 'PAGADO')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF281E59),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showPaymentModal(account),
                  child: const Text('Abonar a Cuenta'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<Map<String, dynamic>> accounts) {
    if (accounts.isEmpty) {
      return const Center(child: Text('No hay cuentas registradas en esta sección.', style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    final groupedAccounts = _groupAccountsByMonth(accounts);
    final keys = groupedAccounts.keys.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width < 600 ? 1 : (width < 950 ? 2 : 3);
        final double childAspectRatio = width < 600 ? 1.9 : (width < 950 ? 1.6 : 1.4);

        return ListView.builder(
          padding: EdgeInsets.all(width < 600 ? 12.0 : 24.0),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final monthKey = keys[index];
            final monthAccounts = groupedAccounts[monthKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 16.0, top: index == 0 ? 0.0 : 24.0),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFF1E1336)),
                      const SizedBox(width: 8),
                      Text(
                        monthKey,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1336),
                        ),
                      ),
                      const Expanded(child: Divider(indent: 16, thickness: 1)),
                    ],
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: monthAccounts.length,
                  itemBuilder: (context, idx) {
                    return _buildAccountCard(monthAccounts[idx]);
                  },
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
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF281E59)),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: (context.isMobile && !Navigator.canPop(context))
            ? null
            : AppBar(
                title: const Text('Cuentas por Pagar', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF1E1336),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(icon: Icon(Icons.pending_actions), text: 'Pendientes'),
                    Tab(icon: Icon(Icons.timelapse), text: 'Parciales'),
                    Tab(icon: Icon(Icons.done_all), text: 'Pagadas (Historial)'),
                  ],
                ),
              ),
        body: Column(
          children: [
            if (context.isMobile && !Navigator.canPop(context))
              Container(
                color: const Color(0xFF1E1336),
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(icon: Icon(Icons.pending_actions), text: 'Pendientes'),
                    Tab(icon: Icon(Icons.timelapse), text: 'Parciales'),
                    Tab(icon: Icon(Icons.done_all), text: 'Pagadas'),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('accounts_payable').stream(primaryKey: ['id']).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF281E59)));
                  }

                  final accounts = snapshot.data!;
                  final pendientes = accounts.where((a) => a['status'] == 'PENDIENTE').toList();
                  final parciales = accounts.where((a) => a['status'] == 'PARCIAL').toList();
                  final pagadas = accounts.where((a) => a['status'] == 'PAGADO').toList();

                  return TabBarView(
                    children: [
                      _buildTabContent(pendientes),
                      _buildTabContent(parciales),
                      _buildTabContent(pagadas),
                    ],
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
