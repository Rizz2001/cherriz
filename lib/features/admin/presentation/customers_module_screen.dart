import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive_layout.dart';

class CustomersModuleScreen extends StatefulWidget {
  const CustomersModuleScreen({super.key});

  @override
  State<CustomersModuleScreen> createState() => _CustomersModuleScreenState();
}

class _CustomersModuleScreenState extends State<CustomersModuleScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> customers = [];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase.from('customers').select().order('name');
      if (mounted) {
        setState(() {
          customers = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar('Error cargando clientes: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
      ),
    );
  }

  Future<void> _showCustomerModal([Map<String, dynamic>? customer]) async {
    final nameController = TextEditingController(text: customer?['name'] ?? '');
    final docController = TextEditingController(
      text: customer?['document_id'] ?? '',
    );
    final phoneController = TextEditingController(
      text: customer?['phone'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(customer == null ? 'Nuevo Cliente' : 'Editar Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Razón Social',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: docController,
                  decoration: const InputDecoration(labelText: 'Cédula / RIF'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final doc = docController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty || doc.isEmpty) {
                  _showSnackBar(
                    'Nombre y Documento son obligatorios',
                    isError: true,
                  );
                  return;
                }

                try {
                  if (customer == null) {
                    await supabase.from('customers').insert({
                      'name': name,
                      'document_id': doc,
                      'phone': phone,
                    });
                  } else {
                    await supabase
                        .from('customers')
                        .update({
                          'name': name,
                          'document_id': doc,
                          'phone': phone,
                        })
                        .eq('id', customer['id']);
                  }

                  if (context.mounted) Navigator.pop(context);
                  _fetchCustomers();
                  _showSnackBar(
                    customer == null
                        ? 'Cliente agregado'
                        : 'Cliente actualizado',
                  );
                } catch (e) {
                  _showSnackBar('Error guardando cliente: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1336),
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E1336)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text(
                'Módulo de Clientes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF1E1336),
              foregroundColor: Colors.white,
            ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return ListTile(
                      title: Text(
                        customer['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${customer['document_id']} | Tel: ${customer['phone'] ?? 'N/A'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF1E1336)),
                        onPressed: () => _showCustomerModal(customer),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        onPressed: () => _showCustomerModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
