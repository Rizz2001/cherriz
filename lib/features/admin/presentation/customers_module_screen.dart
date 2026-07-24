import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_button.dart';
import '../../../core/widgets/cherriz_text_field.dart';
import '../../../core/widgets/cherriz_card.dart';
import '../../../core/widgets/cherriz_modal.dart';

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
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
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
    bool isSaving = false;

    await CherrizModal.show(
      context: context,
      title: customer == null ? 'Nuevo Cliente' : 'Editar Cliente',
      content: StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CherrizTextField(
                controller: nameController,
                labelText: 'Nombre / Razón Social',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: docController,
                labelText: 'Cédula / RIF',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: phoneController,
                labelText: 'Teléfono',
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CherrizButton(
                    text: 'Cancelar',
                    variant: CherrizButtonVariant.ghost,
                    onPressed: isSaving ? null : () => Navigator.pop(modalContext),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CherrizButton(
                    text: 'Guardar',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
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

                            setModalState(() => isSaving = true);

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

                              if (modalContext.mounted) Navigator.pop(modalContext);
                              _fetchCustomers();
                              _showSnackBar(
                                customer == null
                                    ? 'Cliente agregado'
                                    : 'Cliente actualizado',
                              );
                            } catch (e) {
                              if (modalContext.mounted) {
                                setModalState(() => isSaving = false);
                              }
                              _showSnackBar('Error guardando cliente: $e', isError: true);
                            }
                          },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text('Módulo de Clientes'),
              automaticallyImplyLeading: false,
            ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: CherrizCard(
                padding: EdgeInsets.zero,
                child: customers.isEmpty
                    ? const Center(child: Text('No hay clientes registrados', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            title: Text(
                              customer['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${customer['document_id']} | Tel: ${customer['phone'] ?? 'N/A'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showCustomerModal(),
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}
