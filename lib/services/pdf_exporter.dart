import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  // Load Unicode-supported fonts
  final regularFont = await PdfGoogleFonts.nunitoRegular();
  final boldFont = await PdfGoogleFonts.nunitoBold();

  final baseStyle = pw.TextStyle(font: regularFont, fontSize: 10);
  final boldStyle = pw.TextStyle(font: boldFont, fontSize: 10);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
      build: (context) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  campaign.name,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 24,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),

          ],
        ),

        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),

        // Stats
        pw.Row(children: [
          pw.Text('${contributions.length} Contributors',
              style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 11,
                  color: PdfColors.grey700)),
          pw.SizedBox(width: 20),
          pw.Text(
            'Started ${_formatDate(campaign.startDate)}',
            style: pw.TextStyle(
                font: regularFont,
                fontSize: 11,
                color: PdfColors.grey700),
          ),
          if (campaign.targetAmount != null) ...[
            pw.SizedBox(width: 20),
            pw.Text(
              'Target: Ksh ${campaign.targetAmount!.toStringAsFixed(0)}',
              style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 11,
                  color: PdfColors.grey700),
            ),
          ],
        ]),

        pw.SizedBox(height: 24),

        // Table
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('#', style: boldStyle),
                _cell('Name / Phone', style: boldStyle),
                _cell('Amount (Ksh)', style: boldStyle),
                _cell('Date', style: boldStyle),
              ],
            ),
            ...contributions.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final date =
                  DateTime.fromMillisecondsSinceEpoch(c.date);
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven
                      ? PdfColors.white
                      : PdfColors.grey50,
                ),
                children: [
                  _cell('${i + 1}', style: baseStyle),
                  _cell(c.senderName ?? c.senderPhone,
                      style: baseStyle),
                  _cell(c.amount.toStringAsFixed(0),
                      style: baseStyle),
                  _cell(
                      '${date.day}/${date.month}/${date.year}',
                      style: baseStyle),
                ],
              );
            }),
            // Total row
            pw.TableRow(
              
              children: [
                _cell('', style: baseStyle),
                _cell('TOTAL', style: boldStyle),
                _cell(
                  contributions
                      .fold(0.0, (sum, c) => sum + c.amount)
                      .toStringAsFixed(0),
                  style: boldStyle,
                ),
                _cell('', style: baseStyle),
              ],
            ),
          ],
        ),

        // Play store link
        pw.SizedBox(height: 20),
        pw.Text(
          'Generated by M-Ficha ',
          style: pw.TextStyle(
              font: regularFont,
              fontSize: 8,
              color: PdfColors.grey500),
        ),
      ],

      // Watermark
      // : watermark
      //     ? pw.Watermark(
      //         angle: 45,
      //         child: pw.Opacity(
      //           opacity: 0.15,
      //           child: pw.Text(
      //             'FREE VERSION',
      //             style: pw.TextStyle(
      //               font: boldFont,
      //               fontSize: 80,
      //               color: PdfColors.grey,
      //             ),
      //           ),
      //         ),
      //       )
      //     : null,
    ),
  );

  return pdf.save();
}

// Updated _cell to accept style
static pw.Widget _cell(String text, {required pw.TextStyle style}) {
  return pw.Padding(
    padding:
        const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(text, style: style),
  );
}

static String _formatDate(int timestamp) {
  final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${d.day}/${d.month}/${d.year}';
}


  static Future<void> share(Uint8List bytes, String campaignName) async {
    try{
    final dir = await getTemporaryDirectory();
   
    final file = File(
        '${dir.path}/mchango_${campaignName.replaceAll(' ', '_')}.pdf');
        
    await file.writeAsBytes(bytes);
   
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Mchango Report — $campaignName',
    );
    }catch(e){
     debugPrint("Error sharing PDF: $e");
    }

  }
}