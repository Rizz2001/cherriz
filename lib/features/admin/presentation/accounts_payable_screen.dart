import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
                      
                      _showSnackBar('Abono registrado exitosamente');
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      _showSnackBar('Error al procesar el pago: $e', isError: true);
                      setModalState(() => isProcessing = false);
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
        title: const Text('Cuentas por Pagar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
            if (accounts.isEmpty) {
              return const Center(child: Text('No hay cuentas por pagar registradas.'));
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final supplierName = _getSupplierName(account['supplier_id'].toString());
                final totalDebt = (account['total_debt'] as num?)?.toDouble() ?? 0.0;
                final amountPaid = (account['amount_paid'] as num?)?.toDouble() ?? 0.0;
                final status = account['status']?.toString() ?? 'PENDIENTE';
                final dueDateStr = account['due_date']?.toString();
                final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;

                Color statusColor = Colors.redAccent;
                if (status == 'PAGADO') statusColor = Colors.green;
                if (status == 'PARCIAL') statusColor = Colors.orange;

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
                        const Spacer(),
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
              },
            );
          },
        ),
      ),
    );
  }
}
