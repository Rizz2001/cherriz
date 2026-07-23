import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AccountsReceivableScreen extends StatefulWidget {
  const AccountsReceivableScreen({super.key});

  @override
  State<AccountsReceivableScreen> createState() => _AccountsReceivableScreenState();
}

class _AccountsReceivableScreenState extends State<AccountsReceivableScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> receivables = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('accounts_receivable')
          .select('*, customers(*)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          receivables = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error de conexión: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
      ),
    );
  }

  Future<void> _showPaymentModal(Map<String, dynamic> account) async {
    final amountController = TextEditingController();
    final double totalAmount = (account['total_amount'] as num?)?.toDouble() ?? 0.0;
    final double amountPaid = (account['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final double pendingAmount = totalAmount - amountPaid;
    final String invoiceNumber = account['invoice_number']?.toString() ?? 'N/A';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar Cobro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Factura: $invoiceNumber'),
              Text('Pendiente: \$${pendingAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto a Cobrar (\$)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payment = double.tryParse(amountController.text) ?? 0.0;
                if (payment <= 0 || payment > pendingAmount) {
                  _showSnackBar('Monto inválido', isError: true);
                  return;
                }

                try {
                  final newAmountPaid = amountPaid + payment;
                  String newStatus = account['status'] ?? 'PENDIENTE';
                  
                  if (newAmountPaid >= totalAmount) {
                    newStatus = 'PAGADO';
                  } else if (newAmountPaid > 0) {
                    newStatus = 'PARCIAL';
                  }

                  await supabase.from('accounts_receivable').update({
                    'amount_paid': newAmountPaid,
                    'status': newStatus,
                  }).eq('id', account['id']);

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSnackBar('Cobro registrado exitosamente');
                  
                  // Refrescar los datos inmediatamente tras registrar el cobro
                  _fetchData();
                  
                } catch (e) {
                  if (!context.mounted) return;
                  _showSnackBar('Error registrando cobro: $e', isError: true);
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final customer = account['customers'] ?? {};
    final total = (account['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (account['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final pending = total - paid;
    final dueDate = DateTime.tryParse(account['due_date']?.toString() ?? '');
    final String invoiceNumber = account['invoice_number']?.toString() ?? 'N/A';
    final String customerName = customer['name']?.toString() ?? 'Desconocido';
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && account['status'] != 'PAGADO';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 550;
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (account['status'] == 'PAGADO')
                        const Chip(label: Text('Pagado', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Factura: $invoiceNumber'),
                  if (dueDate != null)
                    Text(
                      'Vence: ${DateFormat('dd/MM/yyyy').format(dueDate)}',
                      style: TextStyle(color: isOverdue ? Colors.red : Colors.grey, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Total:\n\$${total.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cobrado:\n\$${paid.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.green, fontSize: 13),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Pendiente:\n\$${pending.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (account['status'] != 'PAGADO') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Cobrar'),
                        onPressed: () => _showPaymentModal(account),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Factura: $invoiceNumber'),
                      if (dueDate != null)
                        Text(
                          'Vence: ${DateFormat('dd/MM/yyyy').format(dueDate)}',
                          style: TextStyle(color: isOverdue ? Colors.red : Colors.grey),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total: \$${total.toStringAsFixed(2)}'),
                      Text('Cobrado: \$${paid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                      Text('Pendiente: \$${pending.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (account['status'] != 'PAGADO')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Cobrar'),
                    onPressed: () => _showPaymentModal(account),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1336), foregroundColor: Colors.white),
                  )
                else
                  const Chip(label: Text('Pagado', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(String status) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final accounts = receivables.where((a) => a['status'] == status).toList();

    if (accounts.isEmpty) return Center(child: Text('No hay cuentas $status'));

    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        return _buildAccountCard(accounts[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF1E1336),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cuentas por Cobrar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _fetchData,
              ),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF1E1336),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Pendientes'),
              Tab(text: 'Parciales'),
              Tab(text: 'Pagadas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList('PENDIENTE'),
              _buildList('PARCIAL'),
              _buildList('PAGADO'),
            ],
          ),
        ),
      ],
    );
  }
}
