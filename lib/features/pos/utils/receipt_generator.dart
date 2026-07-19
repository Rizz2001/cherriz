import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<Uint8List> generateReceipt({
  required Map<String, dynamic> company,
  required List<Map<String, dynamic>> cartItems,
  required List<Map<String, dynamic>> payments,
  required double totalUsd,
  required double totalBs,
  required double exchangeRate,
  required double changeUsd,
  required double changeBs,
}) async {
  final pdf = pw.Document();

  pw.ImageProvider? logoImage;
  final String? logoUrl = company['logo_url'];

  if (logoUrl != null && logoUrl.isNotEmpty) {
    try {
      logoImage = await networkImage(logoUrl);
    } catch (e) {
      // Ignore if image fails to load
    }
  }

  // Define un formato de ticket (roll paper 80mm aprox = 80mm * 2.83 pt/mm = 226 pt de ancho)
  const double width = 80 * 2.83465; // ~226.7 points
  final format = PdfPageFormat(width, double.infinity, marginAll: 10 * 2.83465);

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (logoImage != null) ...[
              pw.Image(logoImage, width: 80),
              pw.SizedBox(height: 10),
            ],

            // Header
            pw.Text(
              company['name'] ?? 'Mi Empresa',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            if (company['rif'] != null && company['rif'].toString().isNotEmpty)
              pw.Text(
                'RIF: ${company['rif']}',
                style: const pw.TextStyle(fontSize: 12),
                textAlign: pw.TextAlign.center,
              ),

            pw.SizedBox(height: 5),
            pw.Text(
              DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Elementos del Carrito
            pw.Column(
              children: cartItems.map((item) {
                final product = item['product'];
                final qty = item['quantity'];
                final price = (product['price_usd'] as num).toDouble();
                final subtotal = price * qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 20,
                        child: pw.Text(
                          '$qty',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          product['name'] ?? 'Producto',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        '\$${subtotal.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Totales
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL USD',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '\$${totalUsd.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL Bs',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Bs. ${totalBs.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Pagos
            pw.Text('MÉTODOS DE PAGO', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.Column(
              children: payments.map((p) {
                final amount = (p['amount'] as num).toDouble();
                final method = p['method'] as String;
                final isUsd = method.contains('USD') || method == 'Zelle';
                final prefix = isUsd ? '\$' : 'Bs.';
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(method, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '$prefix${amount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                );
              }).toList(),
            ),

            // Vuelto
            if (changeUsd > 0) ...[
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VUELTO ENTREGADO',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${changeUsd.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            pw.SizedBox(height: 20),
            pw.Text(
              '*** GRACIAS POR SU COMPRA ***',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
