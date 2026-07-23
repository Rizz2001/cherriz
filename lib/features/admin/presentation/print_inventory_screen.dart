import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/responsive_layout.dart';

class PrintInventoryScreen extends StatefulWidget {
  const PrintInventoryScreen({super.key});

  @override
  State<PrintInventoryScreen> createState() => _PrintInventoryScreenState();
}

class _PrintInventoryScreenState extends State<PrintInventoryScreen> {
  final supabase = Supabase.instance.client;
  bool isGenerating = false;

  Future<void> _generateReport({required bool isPriceList}) async {
    setState(() => isGenerating = true);
    
    try {
      final compRes = await supabase.from('companies').select().limit(1);
      final prodRes = await supabase.from('products').select().eq('is_active', true).order('name');
      
      final companyName = compRes.isNotEmpty ? compRes.first['name'] ?? 'Gran Catador' : 'Gran Catador';
      final exchangeRate = compRes.isNotEmpty ? (compRes.first['exchange_rate'] as num?)?.toDouble() ?? 40.0 : 40.0;
      final products = List<Map<String, dynamic>>.from(prodRes);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  isPriceList ? 'Lista de Precios' : 'Reporte de Stock Actual', 
                  style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)
                ),
                pw.SizedBox(height: 4),
                pw.Text('Fecha: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 12)),
                if (isPriceList)
                  pw.Text('Tasa de Cambio: Bs. ${exchangeRate.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 16),
              ],
            );
          },
          build: (pw.Context context) {
            if (isPriceList) {
              return [
                pw.TableHelper.fromTextArray(
                  headers: ['Producto', 'Categoría', 'Precio USD', 'Precio Bs'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E1336)),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: products.map((p) {
                    final priceUsd = (p['price_usd'] as num?)?.toDouble() ?? 0.0;
                    final priceBs = priceUsd * exchangeRate;
                    return [
                      p['name'] ?? '',
                      p['category'] ?? p['category_id']?.toString() ?? '',
                      '\$${priceUsd.toStringAsFixed(2)}',
                      'Bs. ${priceBs.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                )
              ];
            } else {
              return [
                pw.TableHelper.fromTextArray(
                  headers: ['Producto', 'SKU / Código', 'Stock'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E1336)),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: products.map((p) {
                    final stock = (p['stock'] as num?)?.toInt() ?? 0;
                    final unitsPerBox = (p['units_per_box'] as num?)?.toInt() ?? 1;
                    final upb = unitsPerBox > 0 ? unitsPerBox : 1;
                    final cajas = stock ~/ upb;
                    final sueltas = stock % upb;

                    final stockText = sueltas == 0
                        ? '$stock und.\n($cajas Cajas completas)'
                        : '$stock und.\n($cajas Cajas y $sueltas sueltas)';

                    return [
                      p['name'] ?? '',
                      p['barcode']?.toString() ?? p['sku']?.toString() ?? '',
                      stockText,
                    ];
                  }).toList(),
                )
              ];
            }
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(color: PdfColors.grey),
              ),
            );
          },
        ),
      );

      if (!mounted) return;
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: isPriceList ? 'Lista_Precios_Cherriz' : 'Stock_Cherriz',
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando PDF: $e'),
          backgroundColor: Colors.redAccent,
        )
      );
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: (context.isMobile && !Navigator.canPop(context))
          ? null
          : AppBar(
              title: const Text('Generador de Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1E1336),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 750;
              if (isMobile) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildReportCard(
                      title: 'Lista de Precios',
                      icon: Icons.price_check,
                      description: 'Genera un catálogo en PDF con los productos y sus precios en USD y Bs (calculado con la tasa actual).',
                      onTap: isGenerating ? null : () => _generateReport(isPriceList: true),
                      isMobile: true,
                    ),
                    const SizedBox(height: 24),
                    _buildReportCard(
                      title: 'Stock Actual',
                      icon: Icons.inventory,
                      description: 'Genera un reporte en PDF diseñado para realizar auditorías e inventario físico en el local.',
                      onTap: isGenerating ? null : () => _generateReport(isPriceList: false),
                      isMobile: true,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildReportCard(
                    title: 'Lista de Precios',
                    icon: Icons.price_check,
                    description: 'Genera un catálogo en PDF con los productos y sus precios en USD y Bs (calculado con la tasa actual).',
                    onTap: isGenerating ? null : () => _generateReport(isPriceList: true),
                    isMobile: false,
                  ),
                  const SizedBox(width: 32),
                  _buildReportCard(
                    title: 'Stock Actual',
                    icon: Icons.inventory,
                    description: 'Genera un reporte en PDF diseñado para realizar auditorías e inventario físico en el local.',
                    onTap: isGenerating ? null : () => _generateReport(isPriceList: false),
                    isMobile: false,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback? onTap,
    bool isMobile = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: isMobile ? double.infinity : 350,
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: const Color(0xFF281E59)),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1336)),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1336),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: onTap == null
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Generar PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
