import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cherriz_button.dart';
import '../../../core/widgets/cherriz_text_field.dart';
import '../../../core/widgets/cherriz_card.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSaving = false;
  String? companyId;

  // Controladores Identidad
  final _nameController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  // Controladores Finanzas
  final _exchangeRateController = TextEditingController();
  final _taxPercentageController = TextEditingController();

  // Controladores Tickets
  final _receiptFooterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _exchangeRateController.dispose();
    _taxPercentageController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase.from('companies').select().limit(1);

      if (response.isNotEmpty) {
        final data = response.first;
        companyId = data['id'].toString();
        
        _nameController.text = data['name']?.toString() ?? '';
        _documentIdController.text = data['document_id']?.toString() ?? '';
        _phoneController.text = data['phone']?.toString() ?? '';
        _emailController.text = data['email']?.toString() ?? '';
        _addressController.text = data['address']?.toString() ?? '';
        
        _exchangeRateController.text = data['exchange_rate']?.toString() ?? '0.0';
        _taxPercentageController.text = data['tax_percentage']?.toString() ?? '0.0';
        
        _receiptFooterController.text = data['receipt_footer_message']?.toString() ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (companyId == null) return;
    setState(() => isSaving = true);
    
    final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0.0;
    final taxPercentage = double.tryParse(_taxPercentageController.text) ?? 0.0;

    try {
      await supabase.from('companies').update({
        'name': _nameController.text.trim(),
        'document_id': _documentIdController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'exchange_rate': exchangeRate,
        'tax_percentage': taxPercentage,
        'receipt_footer_message': _receiptFooterController.text.trim(),
      }).eq('id', companyId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: CherrizTextField(
        controller: controller,
        labelText: label,
        prefixIcon: icon,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return CherrizCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil de la Empresa'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;

                    final cardIdentity = _buildCard(
                      title: 'Identidad',
                      children: [
                        _buildTextField(controller: _nameController, label: 'Nombre de la Empresa', icon: Icons.storefront),
                        _buildTextField(controller: _documentIdController, label: 'RIF / Documento', icon: Icons.badge_outlined),
                        _buildTextField(controller: _phoneController, label: 'Teléfono', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                        _buildTextField(controller: _emailController, label: 'Correo Electrónico', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        _buildTextField(controller: _addressController, label: 'Dirección', icon: Icons.location_on_outlined, maxLines: 2),
                      ],
                    );

                    final cardFinance = _buildCard(
                      title: 'Finanzas',
                      children: [
                        _buildTextField(
                          controller: _exchangeRateController,
                          label: 'Tasa de Cambio (Ej: 40.5)',
                          icon: Icons.currency_exchange,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        _buildTextField(
                          controller: _taxPercentageController,
                          label: 'Porcentaje de Impuesto (%)',
                          icon: Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    );

                    final cardTickets = _buildCard(
                      title: 'Tickets y Recibos',
                      children: [
                        _buildTextField(
                          controller: _receiptFooterController,
                          label: 'Mensaje al Pie del Recibo',
                          icon: Icons.receipt_long_outlined,
                          maxLines: 3,
                        ),
                      ],
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          if (isMobile) ...[
                            cardIdentity,
                            const SizedBox(height: AppSpacing.md),
                            cardFinance,
                            const SizedBox(height: AppSpacing.md),
                            cardTickets,
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: cardIdentity),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      cardFinance,
                                      const SizedBox(height: AppSpacing.md),
                                      cardTickets,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          CherrizButton(
                            text: 'Guardar Cambios',
                            icon: Icons.save_outlined,
                            isFullWidth: true,
                            isLoading: isSaving,
                            onPressed: _saveChanges,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
