import 'dart:typed_data';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MchangoPdfExporter {
  static Future<Uint8List> generate({
    required Campaign campaign,
    required List<Contribution> contributions,
    bool watermark = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(campaign.name,
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Ksh ${campaign.totalCollected.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),

          // Stats row
          pw.Row(children: [
            pw.Text('${contributions.length} Contributors',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(width: 20),
            pw.Text(
              'Started ${DateTime.fromMillisecondsSinceEpoch(campaign.startDate).day}/${DateTime.fromMillisecondsSinceEpoch(campaign.startDate).month}/${DateTime.fromMillisecondsSinceEpoch(campaign.startDate).year}',
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey700),
            ),
            if (campaign.targetAmount != null) ...[
              pw.SizedBox(width: 20),
              pw.Text(
                'Target: Ksh ${campaign.targetAmount!.toStringAsFixed(0)}',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey700),
              ),
            ],
          ]),

          pw.SizedBox(height: 24),

          // Table header
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('#', isHeader: true),
                  _cell('Name / Phone', isHeader: true),
                  _cell('Amount (Ksh)', isHeader: true),
                  _cell('Date', isHeader: true),
                ],
              ),
              // Data rows
              ...contributions.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final date = DateTime.fromMillisecondsSinceEpoch(c.date);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : PdfColors.grey50,
                  ),
                  children: [
                    _cell('${i + 1}'),
                    _cell(c.senderName ?? c.senderPhone),
                    _cell(c.amount.toStringAsFixed(0)),
                    _cell('${date.day}/${date.month}/${date.year}'),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green50),
                children: [
                  _cell(''),
                  _cell('TOTAL', isHeader: true),
                  _cell(
                    contributions
                        .fold(0.0, (sum, c) => sum + c.amount)
                        .toStringAsFixed(0),
                    isHeader: true,
                  ),
                  _cell(''),
                ],
              ),
            ],
          ),
        ],

        // Watermark overlay
        // decoration: watermark
        //     ? pw.BoxDecoration(
        //         // Drawn as a background watermark
        //       )
        //     : null,
      ),
    );

    // Add watermark as a separate overlay if needed
    if (watermark) {
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Stack(
            children: [
              pw.Center(
                child: pw.Transform.rotate(
                  angle: -0.5,
                  child: pw.Opacity(
                    opacity: 0.15,
                    child: pw.Text(
                      'FREE VERSION',
                      style: pw.TextStyle(
                        fontSize: 80,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<void> share(Uint8List bytes, String campaignName) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/mchango_${campaignName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Mchango Report — $campaignName',
    );
  }
}