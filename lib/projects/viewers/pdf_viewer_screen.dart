import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:bridge/Server/server_url.dart';

// Drawing classes from previous implementation
class DrawingPath {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;
  DrawingPath({required this.points, required this.color, required this.strokeWidth});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  DrawingPainter({required this.paths});
  @override
  void paint(Canvas canvas, Size size) {
    for (var pathData in paths) {
      final paint = Paint()
        ..color = pathData.color
        ..strokeWidth = pathData.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (int i = 0; i < pathData.points.length - 1; i++) {
        if (pathData.points[i] != null && pathData.points[i + 1] != null) {
          canvas.drawLine(pathData.points[i]!, pathData.points[i + 1]!, paint);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int userId;
  final int fileId;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.userId = 0,
    this.fileId = 0,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  int _currentPage = 1;
  int _totalPages = 0;

  // Drawing feature states
  bool _isDrawingMode = false;
  bool _isErasing = false;
  final Map<int, List<DrawingPath>> _drawings = {};
  DrawingPath? _currentPath;
  Color _drawingColor = Colors.red;
  final double _strokeWidth = 3.0;
  final double _eraserSize = 20.0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadProgressFromServer();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
  
  // --- START: API and Local Storage for Progress ---

  Future<void> _saveCurrentPage(int page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_page_pdf_${widget.filePath}', page);
    } catch (e) {
      debugPrint("Failed to save current page for PDF: $e");
    }
  }

  Future<void> _loadProgressFromServer() async {
    if (widget.userId == 0 || widget.fileId == 0) {
      await _loadLastPageFromLocal();
      return;
    }
    try {
      final uri = Uri.parse('${baseUrl}bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['currentPage'] != null) {
          final serverPage = data['currentPage'] as int;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pdfViewerController.jumpToPage(serverPage);
              setState(() => _currentPage = serverPage);
            });
          return;
        }
      }
      await _loadLastPageFromLocal();
    } catch (e) {
      debugPrint("Server PDF progress fetch failed, trying local: $e");
      await _loadLastPageFromLocal();
    }
  }

  void _updateProgressOnServer(int pageIndex) async {
    if (widget.userId == 0 || widget.fileId == 0) return;
    try {
      await http.post(
        Uri.parse('${baseUrl}Bridge/UpdateFileReadingStatus'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': widget.userId, 'fileId': widget.fileId, 'currentPage': pageIndex}),
      );
    } catch (e) {
      debugPrint("Server PDF progress update failed: $e");
    }
  }

  Future<void> _loadLastPageFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt('last_page_pdf_${widget.filePath}');
      if (lastPage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pdfViewerController.jumpToPage(lastPage);
        });
      }
    } catch (e) {
      debugPrint("Failed to load last visited page for PDF: $e");
    }
  }

  // --- END: Progress Logic ---

  // --- START: Drawing Handlers ---
  
  void _handlePanStart(DragStartDetails details) {
    if (!_isDrawingMode) return;
    final point = details.localPosition;
    setState(() {
      if (_isErasing) {
        _drawings[_currentPage]?.removeWhere((path) =>
            path.points.any((p) => p != null && (p - point).distance < _eraserSize));
      } else {
        _currentPath = DrawingPath(points: [point], color: _drawingColor, strokeWidth: _strokeWidth);
        if (_drawings[_currentPage] == null) _drawings[_currentPage] = [];
        _drawings[_currentPage]!.add(_currentPath!);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode) return;
    final point = details.localPosition;
    setState(() {
      if (_isErasing) {
        _drawings[_currentPage]?.removeWhere((path) =>
            path.points.any((p) => p != null && (p - point).distance < _eraserSize));
      } else if (_currentPath != null) {
        _currentPath!.points.add(point);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDrawingMode) return;
    setState(() {
      _currentPath?.points.add(null);
      _currentPath = null;
    });
  }

  // --- END: Drawing Handlers ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: _isDrawingMode && !_isErasing ? Colors.blue : null),
            tooltip: 'Draw',
            onPressed: () => setState(() {
              _isDrawingMode = _isDrawingMode && !_isErasing ? false : true;
              _isErasing = false;
            }),
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services, color: _isDrawingMode && _isErasing ? Colors.blue : null),
            tooltip: 'Eraser',
            onPressed: () => setState(() {
               _isDrawingMode = _isDrawingMode && _isErasing ? false : true;
               _isErasing = true;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsBottomSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            File(widget.filePath),
            controller: _pdfViewerController,
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() => _currentPage = details.newPageNumber);
              _saveCurrentPage(details.newPageNumber);
              _updateProgressOnServer(details.newPageNumber);
            },
            onDocumentLoaded: (details) {
                setState(() => _totalPages = details.document.pages.count);
            },
          ),
          IgnorePointer(
            ignoring: !_isDrawingMode,
            child: GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: CustomPaint(
                painter: DrawingPainter(paths: _drawings[_currentPage] ?? []),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _totalPages > 0 ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Page $_currentPage of $_totalPages',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ),
      ) : null,
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.warning_amber_rounded),
                title: Text('Font Size Not Available'),
                subtitle: Text('Font size cannot be changed for PDF files.'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.screen_rotation),
                title: const Text('Rotate Screen'),
                onTap: () {
                  final currentOrientation = MediaQuery.of(context).orientation;
                  if (currentOrientation == Orientation.portrait) {
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
            ],
          ),
        );
      },
    );
  }
}
