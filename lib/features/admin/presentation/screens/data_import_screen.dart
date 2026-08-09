import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  _ImportEntity _entity = _ImportEntity.students;
  bool _isReading = false;
  bool _isImporting = false;
  String? _errorMessage;
  String? _fileName;
  List<_ImportRow> _rows = [];

  Future<void> _pickImportFile() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
      _rows = [];
      _fileName = null;
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Spreadsheet',
            extensions: ['csv', 'tsv', 'txt', 'xlsx'],
            mimeTypes: [
              'text/csv',
              'text/plain',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
          ),
        ],
      );
      if (file == null) {
        if (mounted) setState(() => _isReading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final rows = extension == 'xlsx'
          ? _parseXlsx(bytes)
          : _parseDelimited(utf8.decode(bytes, allowMalformed: true));
      if (rows.isEmpty) {
        throw const FormatException('The selected file is empty.');
      }

      final headers = rows.first.map(_normalizeHeader).toList();
      final parsed = <_ImportRow>[];
      for (var i = 1; i < rows.length; i++) {
        final raw = rows[i];
        if (raw.every((cell) => cell.trim().isEmpty)) continue;
        final data = <String, String>{};
        for (var c = 0; c < headers.length; c++) {
          data[headers[c]] = c < raw.length ? raw[c].trim() : '';
        }
        parsed.add(_ImportRow(rowNumber: i + 1, data: data));
      }

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = parsed.map((row) => row.validate(_entity)).toList();
        _isReading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isReading = false;
      });
    }
  }

  Future<void> _runImport() async {
    final validRows = _rows.where((row) => row.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final nextRows = [..._rows];
    for (final row in validRows) {
      final index = nextRows.indexWhere(
        (item) => item.rowNumber == row.rowNumber,
      );
      try {
        final body = {
          'email': row.email,
          'fullName': row.fullName,
          'role': _entity.role,
          if (row.branchId != null) 'branchId': row.branchId,
        };
        final response = await Supabase.instance.client.functions.invoke(
          'provision-user',
          body: body,
        );
        if (response.status != 200) {
          final error = response.data is Map
              ? response.data['error']?.toString()
              : 'Provisioning failed';
          throw Exception(error ?? 'Status ${response.status}');
        }
        nextRows[index] = row.copyWith(
          status: _ImportStatus.success,
          resultMessage: 'Imported',
        );
      } catch (e) {
        nextRows[index] = row.copyWith(
          status: _ImportStatus.failed,
          resultMessage: e.toString(),
        );
      }
      if (mounted) setState(() => _rows = [...nextRows]);
    }

    if (mounted) setState(() => _isImporting = false);
  }

  void _downloadTemplate() {
    final template = _entity.template;
    Clipboard.setData(ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template copied:\n$template'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((row) => row.isValid).length;
    final successCount = _rows
        .where((row) => row.status == _ImportStatus.success)
        .length;
    final failedCount = _rows
        .where(
          (row) =>
              row.status == _ImportStatus.failed ||
              row.status == _ImportStatus.invalid,
        )
        .length;

    return PortalPageShell(
      title: 'Spreadsheet Import Wizard',
      subtitle:
          'Bulk provision students, parents, and teachers from CSV or Excel.',
      icon: Icons.upload_file,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.table_chart,
          label: 'Template',
          onPressed: _downloadTemplate,
        ),
        PortalAction(
          icon: Icons.folder_open,
          label: 'Choose File',
          onPressed: _isReading || _isImporting ? () {} : _pickImportFile,
          primary: true,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<_ImportEntity>(
                  initialValue: _entity,
                  decoration: const InputDecoration(
                    labelText: 'Import type',
                    border: OutlineInputBorder(),
                  ),
                  items: _ImportEntity.values
                      .map(
                        (entity) => DropdownMenuItem(
                          value: entity,
                          child: Text(entity.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isImporting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _entity = value;
                            _rows = _rows
                                .map((row) => row.validate(value))
                                .toList();
                          });
                        },
                ),
              ),
              _ImportPill(
                icon: Icons.insert_drive_file,
                text: _fileName ?? 'No file selected',
              ),
              _ImportPill(icon: Icons.check_circle, text: '$validCount valid'),
              _ImportPill(icon: Icons.done_all, text: '$successCount done'),
              _ImportPill(
                icon: Icons.error_outline,
                text: '$failedCount issues',
              ),
              FilledButton.icon(
                onPressed: _isImporting || validCount == 0 ? null : _runImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isImporting ? 'Importing' : 'Import valid rows'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            PortalErrorBanner(
              message: _errorMessage!,
              onRetry: _pickImportFile,
            ),
          if (_isReading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Expanded(
            child: _rows.isEmpty
                ? _ImportEmptyState(entity: _entity)
                : _ImportPreviewTable(rows: _rows),
          ),
        ],
      ),
    );
  }
}

class _ImportPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ImportPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ImportEmptyState extends StatelessWidget {
  final _ImportEntity entity;

  const _ImportEmptyState({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload_file, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Choose a CSV or Excel file to preview before importing.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(entity.template, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'The first worksheet is imported. Keep the first row as headers matching the template.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportPreviewTable extends StatelessWidget {
  final List<_ImportRow> rows;

  const _ImportPreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Row')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Branch ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Message')),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    color: WidgetStatePropertyAll(row.status.backgroundColor),
                    cells: [
                      DataCell(Text(row.rowNumber.toString())),
                      DataCell(Text(row.fullName)),
                      DataCell(Text(row.email)),
                      DataCell(Text(row.branchId ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              row.status.icon,
                              size: 18,
                              color: row.status.color,
                            ),
                            const SizedBox(width: 6),
                            Text(row.status.label),
                          ],
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(
                            row.resultMessage,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

enum _ImportEntity {
  students('Students', 'student'),
  parents('Parents', 'parent'),
  teachers('Teachers', 'teacher');

  final String label;
  final String role;

  const _ImportEntity(this.label, this.role);

  String get template {
    switch (this) {
      case _ImportEntity.students:
        return 'full_name,email,branch_id\nAhmed Ali,student@example.com,<optional-branch-uuid>';
      case _ImportEntity.parents:
        return 'full_name,email\nParent Name,parent@example.com';
      case _ImportEntity.teachers:
        return 'full_name,email,branch_id\nTeacher Name,teacher@example.com,<optional-branch-uuid>';
    }
  }
}

enum _ImportStatus {
  ready('Ready', Icons.check_circle_outline, AppColors.success),
  invalid('Invalid', Icons.error_outline, AppColors.error),
  success('Imported', Icons.done_all, AppColors.success),
  failed('Failed', Icons.warning_amber, AppColors.warning);

  final String label;
  final IconData icon;
  final Color color;

  const _ImportStatus(this.label, this.icon, this.color);

  Color get backgroundColor => color.withValues(alpha: .06);
}

class _ImportRow {
  final int rowNumber;
  final Map<String, String> data;
  final _ImportStatus status;
  final String resultMessage;

  const _ImportRow({
    required this.rowNumber,
    required this.data,
    this.status = _ImportStatus.ready,
    this.resultMessage = 'Ready',
  });

  String get fullName =>
      data['full_name'] ??
      data['name'] ??
      data['full name'] ??
      data['fullname'] ??
      '';
  String get email => data['email'] ?? data['email_address'] ?? '';
  String? get branchId {
    final value = data['branch_id'] ?? data['branchid'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool get isValid => status == _ImportStatus.ready;

  _ImportRow validate(_ImportEntity entity) {
    final errors = <String>[];
    if (fullName.trim().isEmpty) errors.add('Missing full_name');
    if (email.trim().isEmpty || !email.contains('@')) {
      errors.add('Invalid email');
    }
    if (entity != _ImportEntity.parents && branchId != null) {
      final uuidLike = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuidLike.hasMatch(branchId!)) {
        errors.add('branch_id must be a UUID');
      }
    }
    return copyWith(
      status: errors.isEmpty ? _ImportStatus.ready : _ImportStatus.invalid,
      resultMessage: errors.isEmpty ? 'Ready' : errors.join(', '),
    );
  }

  _ImportRow copyWith({_ImportStatus? status, String? resultMessage}) {
    return _ImportRow(
      rowNumber: rowNumber,
      data: data,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}

String _normalizeHeader(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}

List<List<String>> _parseDelimited(String source) {
  final delimiter = source.contains('\t') && !source.contains(',') ? '\t' : ',';
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (char == '"') {
      if (inQuotes && next == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == delimiter && !inQuotes) {
      currentRow.add(current.toString());
      current.clear();
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && next == '\n') i++;
      currentRow.add(current.toString());
      current.clear();
      rows.add([...currentRow]);
      currentRow.clear();
    } else {
      current.write(char);
    }
  }

  if (current.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(current.toString());
    rows.add([...currentRow]);
  }
  return rows;
}

List<List<String>> _parseXlsx(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = {
    for (final file in archive.files)
      if (file.isFile) file.name: file.content as List<int>,
  };

  final workbookXml = _xlsxText(files, 'xl/workbook.xml');
  final workbookRelsXml = _xlsxText(files, 'xl/_rels/workbook.xml.rels');
  final sheetPath = _firstWorksheetPath(workbookXml, workbookRelsXml);
  final sharedStrings = _readSharedStrings(files);
  final sheetXml = _xlsxText(files, sheetPath);
  final document = XmlDocument.parse(sheetXml);
  final sparseRows = <int, Map<int, String>>{};

  for (final row in document.findAllElements('row')) {
    final rowIndex = int.tryParse(row.getAttribute('r') ?? '') ?? 0;
    if (rowIndex <= 0) continue;

    final values = <int, String>{};
    for (final cell in row.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final colIndex = _xlsxColumnIndex(ref);
      if (colIndex < 0) continue;
      values[colIndex] = _xlsxCellValue(cell, sharedStrings);
    }
    sparseRows[rowIndex - 1] = values;
  }

  if (sparseRows.isEmpty) return const [];
  final maxRow = sparseRows.keys.reduce((a, b) => a > b ? a : b);
  final maxCol = sparseRows.values
      .expand((row) => row.keys)
      .fold<int>(0, (max, col) => col > max ? col : max);

  final rows = <List<String>>[];
  for (var r = 0; r <= maxRow; r++) {
    final sparse = sparseRows[r] ?? const <int, String>{};
    rows.add([for (var c = 0; c <= maxCol; c++) sparse[c] ?? '']);
  }

  return rows
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
}

String _xlsxText(Map<String, List<int>> files, String path) {
  final bytes = files[path];
  if (bytes == null) {
    throw FormatException('Missing XLSX part: $path');
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _firstWorksheetPath(String workbookXml, String relsXml) {
  final workbook = XmlDocument.parse(workbookXml);
  final rels = XmlDocument.parse(relsXml);
  final firstSheet = workbook.findAllElements('sheet').firstOrNull;
  if (firstSheet == null) {
    throw const FormatException('The Excel workbook has no worksheets.');
  }

  final relationId =
      firstSheet.getAttribute('r:id') ?? firstSheet.getAttribute('id');
  if (relationId == null || relationId.isEmpty) {
    throw const FormatException('The first worksheet is missing its relation.');
  }

  final relationship = rels
      .findAllElements('Relationship')
      .firstWhere(
        (rel) => rel.getAttribute('Id') == relationId,
        orElse: () => throw const FormatException(
          'Could not resolve the first worksheet relation.',
        ),
      );
  final target = relationship.getAttribute('Target');
  if (target == null || target.isEmpty) {
    throw const FormatException('The first worksheet relation has no target.');
  }
  return target.startsWith('xl/') ? target : 'xl/$target';
}

List<String> _readSharedStrings(Map<String, List<int>> files) {
  final bytes = files['xl/sharedStrings.xml'];
  if (bytes == null) return const [];
  final document = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
  return document
      .findAllElements('si')
      .map(
        (item) =>
            item.findAllElements('t').map((node) => node.innerText).join(),
      )
      .toList();
}

String _xlsxCellValue(XmlElement cell, List<String> sharedStrings) {
  final type = cell.getAttribute('t');
  final valueNode = cell.findElements('v').firstOrNull;
  final inlineText = cell.findElements('is').firstOrNull;

  if (type == 'inlineStr' && inlineText != null) {
    return inlineText.findAllElements('t').map((node) => node.innerText).join();
  }
  if (valueNode == null) return '';

  final raw = valueNode.innerText;
  if (type == 's') {
    final index = int.tryParse(raw);
    if (index == null || index < 0 || index >= sharedStrings.length) return '';
    return sharedStrings[index];
  }
  if (type == 'b') return raw == '1' ? 'true' : 'false';
  return raw;
}

int _xlsxColumnIndex(String cellRef) {
  final letters = RegExp(
    r'^[A-Z]+',
    caseSensitive: false,
  ).stringMatch(cellRef)?.toUpperCase();
  if (letters == null || letters.isEmpty) return -1;

  var value = 0;
  for (final codeUnit in letters.codeUnits) {
    value = value * 26 + (codeUnit - 64);
  }
  return value - 1;
}
