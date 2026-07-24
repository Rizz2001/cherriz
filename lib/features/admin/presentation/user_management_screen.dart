import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_button.dart';
import '../../../core/widgets/cherriz_text_field.dart';
import '../../../core/widgets/cherriz_card.dart';
import '../../../core/widgets/cherriz_badge.dart';
import '../../../core/widgets/cherriz_data_table.dart';
import '../../../core/widgets/cherriz_modal.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'CAJERO';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('app_users')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuarios: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  CherrizBadgeVariant _getRoleVariant(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return CherrizBadgeVariant.danger;
      case 'GERENTE':
        return CherrizBadgeVariant.warning;
      case 'CAJERO':
      case 'CASHIER':
        return CherrizBadgeVariant.info;
      default:
        return CherrizBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Control de Usuarios'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return _buildMobileView();
                } else {
                  return _buildDesktopView();
                }
              },
            ),
    );
  }

  Future<void> _showCreateUserDialog(BuildContext context) async {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedRole = 'CAJERO';
    bool isCreating = false;

    await CherrizModal.show(
      context: context,
      title: 'Nuevo Usuario',
      content: StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CherrizTextField(
                controller: _nameController,
                labelText: 'Nombre Completo',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: _emailController,
                labelText: 'Correo Electrónico',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              CherrizTextField(
                controller: _passwordController,
                labelText: 'Contraseña',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol del Sistema',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppColors.textMuted),
                ),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                  DropdownMenuItem(value: 'GERENTE', child: Text('GERENTE')),
                  DropdownMenuItem(value: 'CAJERO', child: Text('CAJERO')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => _selectedRole = val);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CherrizButton(
                    text: 'Cancelar',
                    variant: CherrizButtonVariant.ghost,
                    onPressed: isCreating ? null : () => Navigator.pop(modalContext),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CherrizButton(
                    text: 'Crear Usuario',
                    isLoading: isCreating,
                    onPressed: isCreating
                        ? null
                        : () async {
                            setModalState(() => isCreating = true);
                            try {
                              final adminClient = SupabaseClient(
                                'https://dmfvaaiqxefimkyvsavh.supabase.co',
                                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtZnZhYWlxeGVmaW1reXZzYXZoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDQ3NDE0MywiZXhwIjoyMTAwMDUwMTQzfQ.7LtWtBe2aiT3bdrjqEMq85-loxdtZiJe7oBfdd-5ezs',
                              );

                              final authRes = await adminClient.auth.admin.createUser(
                                AdminUserAttributes(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                  emailConfirm: true,
                                ),
                              );

                              if (authRes.user != null) {
                                final newUserId = authRes.user!.id;
                                final compRes = await supabase.from('companies').select('id').limit(1).single();

                                await supabase.from('app_users').insert({
                                  'id': newUserId,
                                  'company_id': compRes['id'],
                                  'full_name': _nameController.text.trim(),
                                  'role': _selectedRole,
                                  'is_active': true,
                                });

                                if (modalContext.mounted) Navigator.pop(modalContext);
                                _fetchUsers();
                              }
                            } catch (e) {
                              if (modalContext.mounted) {
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                                );
                              }
                            } finally {
                              if (modalContext.mounted) {
                                setModalState(() => isCreating = false);
                              }
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

  Future<void> _showEditUserDialog(BuildContext context, Map<String, dynamic> user) async {
    final editNameController = TextEditingController(text: user['full_name']?.toString() ?? '');
    String selectedRole = user['role']?.toString().toUpperCase() ?? 'CAJERO';
    bool isActive = user['is_active'] ?? false;
    bool isSaving = false;

    await CherrizModal.show(
      context: context,
      title: 'Editar Usuario',
      content: StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CherrizTextField(
                controller: editNameController,
                labelText: 'Nombre Completo',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: ['ADMIN', 'GERENTE', 'CAJERO'].contains(selectedRole) ? selectedRole : 'CAJERO',
                decoration: const InputDecoration(
                  labelText: 'Rol del Sistema',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppColors.textMuted),
                ),
                items: ['ADMIN', 'GERENTE', 'CAJERO']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedRole = val!),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: SwitchListTile(
                  title: Text(
                    isActive ? 'Usuario Activo' : 'Usuario Suspendido',
                    style: TextStyle(
                      color: isActive ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: isActive,
                  activeThumbColor: AppColors.success,
                  onChanged: (val) => setModalState(() => isActive = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
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
                    text: 'Guardar Cambios',
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              await supabase.from('app_users').update({
                                'full_name': editNameController.text.trim(),
                                'role': selectedRole,
                                'is_active': isActive,
                              }).eq('id', user['id']);

                              if (modalContext.mounted) Navigator.pop(modalContext);
                              _fetchUsers();
                            } catch (e) {
                              if (modalContext.mounted) {
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                                );
                              }
                            } finally {
                              if (modalContext.mounted) {
                                setModalState(() => isSaving = false);
                              }
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

  Widget _buildMobileView() {
    if (_users.isEmpty) {
      return const Center(child: Text('No hay usuarios registrados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final bool isActive = user['is_active'] ?? false;
        final String role = user['role']?.toString().toUpperCase() ?? 'DESCONOCIDO';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: CherrizCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? 'Sin Nombre',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CherrizBadge(
                            text: role,
                            variant: _getRoleVariant(role),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          CherrizBadge(
                            text: isActive ? 'Activo' : 'Inactivo',
                            variant: isActive ? CherrizBadgeVariant.success : CherrizBadgeVariant.danger,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  onPressed: () => _showEditUserDialog(context, user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopView() {
    if (_users.isEmpty) {
      return const Center(child: Text('No hay usuarios registrados.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: CherrizCard(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: CherrizDataTable(
            columns: const [
              DataColumn(label: Text('Nombre de Usuario')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: _users.map((user) {
              final bool isActive = user['is_active'] ?? false;
              final String role = user['role']?.toString().toUpperCase() ?? 'DESCONOCIDO';

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          radius: 16,
                          child: const Icon(Icons.person, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          user['full_name'] ?? 'Sin Nombre',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    CherrizBadge(
                      text: role,
                      variant: _getRoleVariant(role),
                    ),
                  ),
                  DataCell(
                    CherrizBadge(
                      text: isActive ? 'Activo' : 'Inactivo',
                      variant: isActive ? CherrizBadgeVariant.success : CherrizBadgeVariant.danger,
                      icon: isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                    ),
                  ),
                  DataCell(
                    CherrizButton(
                      text: 'Editar',
                      variant: CherrizButtonVariant.secondary,
                      icon: Icons.edit_outlined,
                      onPressed: () => _showEditUserDialog(context, user),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
