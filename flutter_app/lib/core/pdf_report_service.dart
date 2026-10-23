import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  static Future<void> generateAndShare({
    required String studentName,
    required String className,
    required Map<String, dynamic> progress,
    required int completionPercent,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EduLink Report Card', style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Generated ${DateTime.now().toLocal()}'.split('.')[0], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Divider(height: 32),
                pw.Text('Student: $studentName', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Class: $className', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 24),
                pw.Text('Overall completion: $completionPercent%', style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                _row('Lessons viewed', '${progress['lessons_viewed']} / ${progress['lessons_total']}'),
                _row('Assignments submitted', '${progress['assignments_submitted']} / ${progress['assignments_total']}'),
                _row('Quizzes taken', '${progress['quizzes_taken']}'),
                _row('Average quiz score', '${progress['avg_quiz_score']}%'),
                _row('Last activity', '${progress['last_activity'] ?? 'N/A'}'),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(
                    completionPercent >= 80
                        ? 'Excellent progress! Keep up the great work.'
                        : completionPercent >= 50
                            ? 'Good progress - a bit more consistency will help.'
                            : 'This student would benefit from extra support and encouragement.',
                    style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Lets the user save, print, or share the PDF - works on both mobile and desktop.
    await Printing.sharePdf(bytes: await doc.save(), filename: '${studentName}_report_card.pdf');
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
