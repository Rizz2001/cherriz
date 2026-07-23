import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<void> generateCashReportPdf({
  required String sessionId,
  required Map<String, dynamic> company,
  required Map<String, dynamic> sessionData,
}) async {
  final supabase = Supabase.instance.client;
  
  // 1. Obtener todas las ventas de este turno junto con sus pagos
  final salesResponse = await supabase
      .from('sales')
      .select('*, sale_payments(*)')
      .eq('session_id', sessionId);

  // 2. Calcular totales
  double totalSalesUsd = 0.0;
  
  Map<String, double> paymentMethodsTotal = {
    'EFECTIVO_USD': 0.0,
    'EFECTIVO_BS': 0.0,
    'PAGO_MOVIL': 0.0,
    'TRANSFERENCIA': 0.0,
    'PUNTO_DE_VENTA': 0.0,
  };

  for (var sale in salesResponse) {
    totalSalesUsd += (sale['total_amount_usd'] as num?)?.toDouble() ?? 0.0;
    
    final payments = sale['sale_payments'] as List<dynamic>? ?? [];
    for (var payment in payments) {
      final method = payment['payment_method']?.toString().toUpperCase() ?? 'OTRO';
      final currency = payment['currency']?.toString().toUpperCase() ?? 'USD';
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
      
      if (method == 'EFECTIVO' && currency == 'USD') {
        paymentMethodsTotal['EFECTIVO_USD'] = (paymentMethodsTotal['EFECTIVO_USD'] ?? 0) + amount;
      } else if (method == 'EFECTIVO' && currency == 'BS') {
        paymentMethodsTotal['EFECTIVO_BS'] = (paymentMethodsTotal['EFECTIVO_BS'] ?? 0) + amount;
      } else {
        paymentMethodsTotal[method] = (paymentMethodsTotal[method] ?? 0) + amount;
      }
    }
  }

  // 3. Obtener información base
  final openedAt = sessionData['created_at'] != null ? DateTime.parse(sessionData['created_at']).toLocal() : DateTime.now();
  final closedAt = sessionData['closed_at'] != null ? DateTime.parse(sessionData['closed_at']).toLocal() : DateTime.now();
  
  final openingBalanceUsd = (sessionData['opening_balance_usd'] as num?)?.toDouble() ?? 0.0;
  final openingBalanceBs = (sessionData['opening_balance_bs'] as num?)?.toDouble() ?? 0.0;

  // 4. Preparar documento PDF
  final pdf = pw.Document();
  final font = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  const double width = 80 * 2.83465; // ~226.7 points
  final format = PdfPageFormat(width, double.infinity, marginAll: 10 * 2.83465);

  pw.ImageProvider? logoImage;
  final String? logoUrl = company['logo_url'];
  if (logoUrl != null && logoUrl.isNotEmpty) {
    try {
      logoImage = await networkImage(logoUrl);
    } catch (e) {
      // Ignorar
    }
  }

  final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (logoImage != null) ...[
              pw.Image(logoImage, width: 80),
              pw.SizedBox(height: 10),
            ],
            pw.Text(
              company['name'] ?? 'Mi Empresa',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            if (company['rif'] != null && company['rif'].toString().isNotEmpty)
              pw.Text('RIF: ${company["rif"]}', style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            pw.Text('REPORTE CORTE Z', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            
            pw.Container(
              width: double.infinity,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Apertura: ${formatter.format(openedAt)}'),
                  pw.Text('Cierre: ${formatter.format(closedAt)}'),
                  pw.Text('Turno ID: ${sessionId.substring(0, 8)}'),
                ]
              )
            ),
            pw.Divider(),

            pw.Container(
              width: double.infinity,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FONDO INICIAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Efectivo USD:'), pw.Text('\$${openingBalanceUsd.toStringAsFixed(2)}')
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Efectivo Bs:'), pw.Text('Bs ${openingBalanceBs.toStringAsFixed(2)}')
                  ]),
                  pw.SizedBox(height: 10),
                  
                  pw.Text('VENTAS TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total Facturado (USD):'), pw.Text('\$${totalSalesUsd.toStringAsFixed(2)}')
                  ]),
                  pw.SizedBox(height: 10),
                  
                  pw.Text('DESGLOSE DE COBROS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...paymentMethodsTotal.entries.where((e) => e.value > 0).map((entry) {
                    final isBs = !entry.key.contains('USD');
                    final prefix = isBs ? 'Bs ' : '\$';
                    final name = entry.key.replaceAll('_', ' ');
                    return pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(name),
                        pw.Text('$prefix${entry.value.toStringAsFixed(2)}')
                      ]
                    );
                  }),
                  
                  pw.Divider(),
                  pw.Text('TOTAL CAJA ESPERADO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Efectivo USD (Apertura + Cobros):'), 
                    pw.Text('\$${(openingBalanceUsd + (paymentMethodsTotal["EFECTIVO_USD"] ?? 0)).toStringAsFixed(2)}')
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Efectivo Bs (Apertura + Cobros):'), 
                    pw.Text('Bs ${(openingBalanceBs + (paymentMethodsTotal["EFECTIVO_BS"] ?? 0)).toStringAsFixed(2)}')
                  ]),
                ]
              )
            ),
            
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('Fin del Reporte', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 20), // Margen para el corte del papel
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'corte_z_$sessionId.pdf',
  );
}
