import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive_layout.dart';

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
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showSupplierModal([Map<String, dynamic>? supplier]) async {
    final isEditing = supplier != null;
    final nameController = TextEditingController(text: isEditing ? supplier['name'] : '');
    final contactController = TextEditingController(text: isEditing ? (supplier['contact_info'] ?? '') : '');
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1336),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Proveedor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono / Contacto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1336),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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

                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              _showSnackBar(isEditing ? 'Proveedor actualizado' : 'Proveedor creado');
                              _fetchSuppliers();
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              _showSnackBar('Error: $e', isError: true);
                            }
                          },
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(isEditing ? 'Actualizar' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSupplier(String supplierId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1336))),
        content: const Text('¿Seguro que desea eliminar este proveedor?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text('Proveedores', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1E1336),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF281E59)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _filterSuppliers,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o contacto...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          if (filteredSuppliers.isEmpty) {
                            return const Center(child: Text('No hay proveedores encontrados', style: TextStyle(color: Colors.grey)));
                          }
                          return ListView.separated(
                            itemCount: filteredSuppliers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final sup = filteredSuppliers[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(sup['name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Contacto: ${sup['contact_info'] ?? '-'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showSupplierModal(sup),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteSupplier(sup['id'].toString()),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F9)),
                                columns: const [
                                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Contacto / Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _showSupplierModal(sup),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
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
        backgroundColor: const Color(0xFF1E1336),
        foregroundColor: Colors.white,
        onPressed: () => _showSupplierModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
