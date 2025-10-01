import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XlsxViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  // Added for API consistency, though not used for progress
  final int userId;
  final int fileId;

  const XlsxViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
    this.userId = 0,
    this.fileId = 0,
  }) : super(key: key);

  @override
  State<XlsxViewerScreen> createState() => _XlsxViewerScreenState();
}

class _XlsxViewerScreenState extends State<XlsxViewerScreen> {
  List<List<DataCell>> _cells = [];
  List<DataColumn> _columns = [];
  bool _isLoading = true;
  String? _error;
  double _fontSize = 14.0; // Default DataTable font size

  @override
  void initState() {
    super.initState();
    _loadSettingsAndExcel();
  }
  
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadSettingsAndExcel() async {
    await _loadFontSize();
    await _loadExcelFile();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('font_size_xlsx') ?? 14.0;
    });
  }

  Future<void> _saveFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_xlsx', _fontSize);
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

      final List<DataColumn> tempColumns = sheet.rows[0]
          .map((cell) => DataColumn(label: Text(cell?.value?.toString() ?? '')))
          .toList();

      final List<List<DataCell>> tempCells = [];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every((cell) => cell == null || cell.value.toString().isEmpty)) continue;
        tempCells.add(row.map((cell) => DataCell(Text(cell?.value?.toString() ?? ''))).toList());
      }

      setState(() {
        _columns = tempColumns;
        _cells = tempCells;
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
    // Rebuild rows with the current font size
    final List<DataRow> dataRows = _cells.map((cellList) {
      return DataRow(cells: cellList);
    }).toList();
    
    // Apply font size to theme for DataTable
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme.copyWith(
      dataTextStyle: TextStyle(fontSize: _fontSize, color: Colors.black87),
      headingTextStyle: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.bold, color: Colors.black),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsBottomSheet(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Theme(
                      data: theme.copyWith(dataTableTheme: dataTableTheme),
                      child: DataTable(
                        columns: _columns,
                        rows: dataRows,
                        border: TableBorder.all(color: Colors.grey.shade400),
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                children: <Widget>[
                  const ListTile(
                    leading: Icon(Icons.format_size),
                    title: Text('Text Size'),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 8.0,
                    max: 24.0,
                    divisions: 8,
                    label: _fontSize.round().toString(),
                    onChanged: (double value) {
                      setStateSheet(() => _fontSize = value);
                      setState(() => _fontSize = value);
                      _saveFontSize();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.screen_rotation),
                    title: const Text('Rotate Screen'),
                    onTap: () {
                      final o = MediaQuery.of(context).orientation;
                      if (o == Orientation.portrait) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.landscapeRight,
                          DeviceOrientation.landscapeLeft,
                        ]);
                      } else {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                      }
                      Navigator.pop(context);
                    },
                  ),
                   const Divider(),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Drawing Not Available'),
                    subtitle: Text('Drawing is not supported on XLSX files.'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
