import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';

class XlsxViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const XlsxViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<XlsxViewerScreen> createState() => _XlsxViewerScreenState();
}

class _XlsxViewerScreenState extends State<XlsxViewerScreen> {
  List<DataColumn> _columns = [];
  List<DataRow> _rows = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExcelFile();
  }

  Future<void> _loadExcelFile() async {
    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.maxRows == 0) {
        setState(() {
          _error = "This Excel file is empty.";
          _isLoading = false;
        });
        return;
      }

      // Columns
      final List<DataColumn> tempColumns = sheet.rows[0]
          .map((cell) => DataColumn(label: Text(cell?.value?.toString() ?? '')))
          .toList();

      // Rows
      final List<DataRow> tempRows = [];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every((cell) => cell == null || cell.value.toString().isEmpty)) continue;

        tempRows.add(DataRow(
            cells: row.map((cell) => DataCell(Text(cell?.value?.toString() ?? ''))).toList()));
      }

      setState(() {
        _columns = tempColumns;
        _rows = tempRows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load Excel file: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: _columns,
                      rows: _rows,
                      border: TableBorder.all(color: Colors.grey.shade400),
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                    ),
                  ),
                ),
    );
  }
}
