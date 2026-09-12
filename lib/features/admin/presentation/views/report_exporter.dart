import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportExporter {
  ReportExporter._();

  static String _escapeCsvCell(dynamic value) {
    if (value == null) return '';
    String str = value.toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"$str"';
    }
    return str;
  }

  /// Generates a standard comma-separated values (CSV) string.
  static String generateCsv(List<String> headers, List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln(headers.map(_escapeCsvCell).join(','));
    // Rows
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  /// Exports data as a CSV file and opens the platform share sheet.
  static Future<void> exportCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final csvContent = generateCsv(headers, rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  /// Exports data as a PDF document and opens the platform share sheet.
  static Future<void> exportPdf({
    required String filename,
    required String reportTitle,
    required String filterDescription,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'ICEM Bus Management Portal - Reports',
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.Text(
            'Filter Date Range: $filterDescription',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  /// Generates a beautiful A5 PDF receipt and triggers sharing
  static Future<void> exportReceipt({required Map<String, dynamic> payment}) async {
    final pdf = pw.Document();

    final name = payment['studentName'] ?? 'Unknown';
    final amount = payment['amount'] ?? 0;
    final status = payment['paymentStatus'] ?? 'Pending';
    final dateField = payment['createdAt'] ?? payment['paymentDate'];
    final paymentMethod = payment['paymentMethod'] ?? 'Online Payment';
    final receiptId = payment['receiptId'] ?? payment['id'] ?? 'N/A';
    final transactionId = payment['transactionId'] ?? 'N/A';
    final prn = payment['prn'] ?? 'N/A';
    final course = payment['course'] ?? 'N/A';
    final route = payment['route'] ?? 'N/A';
    final boarding = payment['boardingStop'] ?? 'N/A';
    final destination = payment['destinationStop'] ?? 'N/A';
    final fare = payment['amount'] ?? amount;

    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.indigo900, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'INDIRA COLLEGE OF ENGINEERING & MANAGEMENT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.indigo900),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'ICEM BUS SERVICE RECEIPT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.indigo900),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 6),

              _pdfRow('Receipt ID:', receiptId, isBold: true),
              _pdfRow('Transaction ID:', transactionId),
              _pdfRow('Date & Time:', dateStr),
              _pdfRow('Student Name:', name, isBold: true),
              _pdfRow('PRN:', prn),
              _pdfRow('Course:', course),

              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),

              _pdfRow('Bus Route:', route),
              _pdfRow('Boarding Stop:', boarding),
              _pdfRow('Destination:', destination),

              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),

              _pdfRow('Fare Amount:', 'INR ${fare is num ? fare.toStringAsFixed(2) : fare}', isBold: true),
              _pdfRow('Payment Method:', paymentMethod),
              _pdfRow('Payment Status:', status,
                  isBold: true,
                  color: status == 'Paid' || status == 'Success' || status == 'Successful'
                      ? PdfColors.green700
                      : (status == 'Failed' ? PdfColors.red700 : PdfColors.amber800)),

              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Thank you for using ICEM Bus Services!',
                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/receipt_$receiptId.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Receipt $receiptId');
  }

  static pw.Widget _pdfRow(String label, String value, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
