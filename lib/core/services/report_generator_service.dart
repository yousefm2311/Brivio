import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportGeneratorService {
  /// Generates a PDF report for Student Grades and Missing Homeworks.
  Future<void> generateGradesReport({
    required String className,
    required List<Map<String, dynamic>> studentsData,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Student Grades Report - $className', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Student Name', 'Exam Score', 'Homework Score', 'Missing Assignments'],
            ...studentsData.map((student) => [
              student['name']?.toString() ?? '',
              student['exam_score']?.toString() ?? '0',
              student['homework_score']?.toString() ?? '0',
              student['missing_assignments']?.toString() ?? '0',
            ]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey))),
        ),
      ],
    ));

    await _saveAndSharePdf(pdf, 'Grades_Report_$className.pdf');
  }

  /// Generates a PDF report for Student Attendance records.
  Future<void> generateAttendanceReport({
    required String className,
    required List<Map<String, dynamic>> attendanceData,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Attendance Report - $className', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Student Name', 'Total Present', 'Total Absent', 'Absence Dates'],
            ...attendanceData.map((record) => [
              record['name']?.toString() ?? '',
              record['present']?.toString() ?? '0',
              record['absent']?.toString() ?? '0',
              record['absence_dates']?.toString() ?? '',
            ]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey))),
        ),
      ],
    ));

    await _saveAndSharePdf(pdf, 'Attendance_Report_$className.pdf');
  }

  /// Generates a PDF report for Financial Tracking (Admin only).
  Future<void> generateFinancialReport({
    required List<Map<String, dynamic>> financialData,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Date', 'Description', 'Type', 'Amount', 'Notes'],
            ...financialData.map((record) => [
              record['date']?.toString() ?? '',
              record['description']?.toString() ?? '',
              record['type']?.toString() ?? '',
              record['amount']?.toString() ?? '0',
              record['notes']?.toString() ?? '',
            ]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey))),
        ),
      ],
    ));

    await _saveAndSharePdf(pdf, 'Financial_Report.pdf');
  }

  /// Generates a PDF report for Teacher Metrics
  Future<void> generateTeacherMetricsReport({
    required List<Map<String, dynamic>> teacherData,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Teacher Metrics Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Teacher Name', 'Classes Taught', 'Average Attendance (%)'],
            ...teacherData.map((record) => [
              record['name']?.toString() ?? '',
              record['classes_taught']?.toString() ?? '0',
              record['avg_attendance']?.toString() ?? '0',
            ]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey))),
        ),
      ],
    ));

    await _saveAndSharePdf(pdf, 'Teacher_Metrics_Report.pdf');
  }

  Future<void> _saveAndSharePdf(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      throw Exception('Could not save the PDF report: $e');
    }
  }
}
