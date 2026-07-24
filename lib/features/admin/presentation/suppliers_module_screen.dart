import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_button.dart';
import '../../../core/widgets/cherriz_text_field.dart';
import '../../../core/widgets/cherriz_card.dart';
import '../../../core/widgets/cherriz_data_table.dart';
import '../../../core/widgets/cherriz_modal.dart';

class SuppliersModuleScreen extends StatefulWidget {
  const SuppliersModuleScreen({super.key});

  @override
  State<SuppliersModuleScreen> createState() => _SuppliersModuleScreenState();
}

class _SuppliersModuleScreenState extends State<SuppliersModuleScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> filteredSuppliers = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    try {
      final res = await supabase.from('suppliers').select().order('name');
      if (!mounted) return;
      setState(() {
        suppliers = List<Map<String, dynamic>>.from(res);
        _filterSuppliers(searchQuery);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando proveedores: $e', isError: true);
    }
  }

  void _filterSuppliers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredSuppliers = List.from(suppliers);
      } else {
        final lowerQuery = query.toLowerCase();
        filteredSuppliers = suppliers.where((s) {
          final nameMatch = (s['name']?.toString().toLowerCase() ?? '').contains(lowerQuery);
          final contactMatch = (s['contact_info']?.toString().toLowerCase() ?? '').contains(lowerQuery);
          return nameMatch || contactMatch;
        }).toList();
      }
    });
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

  Future<void> _showSupplierModal([Map<String, dynamic>? supplier]) async {
    final isEditing = supplier != null;
    final nameController = TextEditingController(text: isEditing ? supplier['name'] : '');
    final contactController = TextEditingController(text: isEditing ? (supplier['contact_info'] ?? '') : '');
    bool isSaving = false;

    await CherrizModal.show(
      context: context,
      title: isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
      content: StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CherrizTextField(
                controller: nameController,
                labelText: 'Nombre del Proveedor',
                prefixIcon: Icons.storefront_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: contactController,
                labelText: 'Teléfono / Contacto',
                prefixIcon: Icons.contact_phone_outlined,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CherrizButton(
                    text: 'Cancelar',
                    variant: CherrizButtonVariant.ghost,
                    onPressed: isSaving ? null : () => Navigator.of(modalContext).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CherrizButton(
                    text: isEditing ? 'Actualizar' : 'Guardar',
                    isLoading: isSaving,
                    onPressed: isSaving ? null : () async {
                      final name = nameController.text.trim();
                      final contactInfo = contactController.text.trim();

                      if (name.isEmpty) {
                        _showSnackBar('El nombre es obligatorio', isError: true);
                        return;
                      }

                      setModalState(() => isSaving = true);

                      try {
                        final data = {
                          'name': name,
                          'contact_info': contactInfo,
                        };

                        if (isEditing) {
                          await supabase.from('suppliers').update(data).eq('id', supplier['id']);
                        } else {
                          await supabase.from('suppliers').insert(data);
                        }

                        if (!modalContext.mounted) return;
                        Navigator.of(modalContext).pop();
                        _showSnackBar(isEditing ? 'Proveedor actualizado' : 'Proveedor creado');
                        _fetchSuppliers();
                      } catch (e) {
                        if (modalContext.mounted) {
                          setModalState(() => isSaving = false);
                        }
                        _showSnackBar('Error: $e', isError: true);
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

  Future<void> _deleteSupplier(String supplierId) async {
    final confirm = await CherrizModal.show<bool>(
      context: context,
      title: 'Confirmar Eliminación',
      isDestructive: true,
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
      onCancel: () => Navigator.pop(context, false),
      onConfirm: () => Navigator.pop(context, true),
      content: const Text(
        '¿Seguro que desea eliminar este proveedor?',
        style: TextStyle(fontSize: 16),
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('suppliers').delete().eq('id', supplierId);
      _showSnackBar('Proveedor eliminado exitosamente');
      _fetchSuppliers();
    } catch (e) {
      _showSnackBar('Error al eliminar (puede tener productos asociados): $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text('Proveedores'),
              automaticallyImplyLeading: false,
            ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CherrizTextField(
                          onChanged: _filterSuppliers,
                          hintText: 'Buscar por nombre o contacto...',
                          prefixIcon: Icons.search,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          if (filteredSuppliers.isEmpty) {
                            return const Center(child: Text('No hay proveedores encontrados', style: TextStyle(color: AppColors.textMuted)));
                          }
                          return ListView.separated(
                            itemCount: filteredSuppliers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final sup = filteredSuppliers[index];
                              return CherrizCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(sup['name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Contacto: ${sup['contact_info'] ?? '-'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: AppColors.primaryAccent),
                                        onPressed: () => _showSupplierModal(sup),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                        onPressed: () => _deleteSupplier(sup['id'].toString()),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        if (filteredSuppliers.isEmpty) {
                          return const Center(child: Text('No hay proveedores encontrados', style: TextStyle(color: AppColors.textMuted)));
                        }

                        return CherrizCard(
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            width: double.infinity,
                            child: CherrizDataTable(
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text('Contacto / Teléfono')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: filteredSuppliers.map((sup) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(sup['id']?.toString().substring(0, 8) ?? '-')),
                                    DataCell(Text(sup['name'] ?? 'Sin nombre')),
                                    DataCell(Text(sup['contact_info'] ?? '-')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryAccent),
                                            onPressed: () => _showSupplierModal(sup),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                            onPressed: () => _deleteSupplier(sup['id'].toString()),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
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
        heroTag: null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showSupplierModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
