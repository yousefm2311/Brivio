import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportGeneratorService {
  /// Generates a CSV report for Student Grades and Missing Homeworks.
  Future<void> generateGradesReport({
    required String className,
    required List<Map<String, dynamic>> studentsData,
  }) async {
    List<List<dynamic>> rows = [];
    
    // Header row
    rows.add([
      'Student Name',
      'Exam Score',
      'Homework Score',
      'Missing Assignments',
    ]);

    for (var student in studentsData) {
      rows.add([
        student['name']?.toString() ?? '',
        student['exam_score']?.toString() ?? '0',
        student['homework_score']?.toString() ?? '0',
        student['missing_assignments']?.toString() ?? '0',
      ]);
    }

    await _saveAndShareCsv(rows, 'Grades_Report_$className.csv');
  }

  /// Generates a CSV report for Student Attendance records.
  Future<void> generateAttendanceReport({
    required String className,
    required List<Map<String, dynamic>> attendanceData,
  }) async {
    List<List<dynamic>> rows = [];
    
    // Header row
    rows.add([
      'Student Name',
      'Total Present',
      'Total Absent',
      'Absence Dates',
    ]);

    for (var record in attendanceData) {
      rows.add([
        record['name']?.toString() ?? '',
        record['present']?.toString() ?? '0',
        record['absent']?.toString() ?? '0',
        record['absence_dates']?.toString() ?? '',
      ]);
    }

    await _saveAndShareCsv(rows, 'Attendance_Report_$className.csv');
  }

  /// Generates a CSV report for Financial Tracking (Admin only).
  Future<void> generateFinancialReport({
    required List<Map<String, dynamic>> financialData,
  }) async {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Date',
      'Description',
      'Type (Inflow/Outflow)',
      'Amount',
      'Notes (Exceptions/Discounts)',
    ]);

    for (var record in financialData) {
      rows.add([
        record['date']?.toString() ?? '',
        record['description']?.toString() ?? '',
        record['type']?.toString() ?? '',
        record['amount']?.toString() ?? '0',
        record['notes']?.toString() ?? '',
      ]);
    }

    await _saveAndShareCsv(rows, 'Financial_Report.csv');
  }

  Future<void> _saveAndShareCsv(List<List<dynamic>> rows, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      String csvData = Csv().encode(rows);
      await file.writeAsString(csvData);
      
      await Share.shareXFiles([XFile(filePath)], text: 'Generated Report: $fileName');
    } catch (e) {
      throw Exception('Could not save or share the report: $e');
    }
  }
}
