import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data_model.dart';
import 'parser_logic.dart';

// Drawing Classes
class DrawingPath {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


class PptxViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  // Added for API integration
  final int userId;
  final int fileId;
  
  const PptxViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
    this.userId = 0,
    this.fileId = 0,
  }) : super(key: key);

  @override
  State<PptxViewerScreen> createState() => _PptxViewerScreenState();
}

class _PptxViewerScreenState extends State<PptxViewerScreen> {
  PptxPresentation? _presentation;
  bool _isLoading = true;
  String _error = '';
  int _currentPage = 0;
  final PageController _pageController = PageController();

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
    _loadAndParseDocument();
  }
  
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAndParseDocument() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) throw Exception("File does not exist.");

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final parser = PptxParser(archive);
      final presentation = await parser.parseDocument();
      
      if (mounted) {
        setState(() {
          _presentation = presentation;
        });
        // Load progress after presentation is ready
        if (presentation.slides.isNotEmpty) {
          await _loadProgressFromServer();
        }
      }
    } catch (e, s) {
      if (mounted) {
        String errorMessage = "Failed to read presentation: ${e.toString()}\n$s";
        if (e is ArchiveException ||
            !widget.fileName.toLowerCase().endsWith('.pptx')) {
          errorMessage =
              "Failed to open file. This viewer supports modern .pptx files only.";
        }
        setState(() => _error = errorMessage);
      }
    } finally {
        if(mounted) setState(() => _isLoading = false);
    }
  }
  
  // --- START: Progress Saving and Loading Logic ---
  Future<void> _saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_pptx_${widget.filePath}', page);
  }

  Future<void> _loadProgressFromServer() async {
    if (widget.userId == 0 || widget.fileId == 0) {
      await _loadLastPageFromLocal();
      return;
    }
    try {
      final uri = Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['currentPage'] != null) {
          final serverPage = (data['currentPage'] as num).toInt();
          if (serverPage > 0 && serverPage <= _presentation!.slides.length) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(serverPage - 1);
                setState(() => _currentPage = serverPage - 1);
              }
            });
            return;
          }
        }
      }
      await _loadLastPageFromLocal();
    } catch (e) {
      await _loadLastPageFromLocal();
    }
  }

  void _updateProgressOnServer(int page) async {
    if (widget.userId == 0 || widget.fileId == 0) return;
    try {
      await http.post(
        Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/Bridge/UpdateFileReadingStatus'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': widget.userId, 'fileId': widget.fileId, 'currentPage': page}),
      );
    } catch (e) {
      debugPrint("Server pptx progress update failed: $e");
    }
  }

  Future<void> _loadLastPageFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final page = prefs.getInt('last_page_pptx_${widget.filePath}');
    if (page != null && page < _presentation!.slides.length) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(page);
          setState(() => _currentPage = page);
        }
      });
    }
  }
  // --- END: Progress Logic ---
  
  // --- START: Drawing Handlers ---
  void _handlePanStart(DragStartDetails details, Size slideSize) {
    if (!_isDrawingMode) return;
    // Normalize position based on the slide's rendered size
    final RenderBox box = context.findRenderObject() as RenderBox;
    final point = box.globalToLocal(details.globalPosition);

    setState(() {
      if (_isErasing) {
        _drawings[_currentPage]?.removeWhere((path) => path.points
            .any((p) => p != null && (p - point).distance < _eraserSize));
      } else {
        _currentPath = DrawingPath(points: [point], color: _drawingColor, strokeWidth: _strokeWidth);
        if (_drawings[_currentPage] == null) _drawings[_currentPage] = [];
        _drawings[_currentPage]!.add(_currentPath!);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size slideSize) {
    if (!_isDrawingMode) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final point = box.globalToLocal(details.globalPosition);

    setState(() {
      if (_isErasing) {
         _drawings[_currentPage]?.removeWhere((path) => path.points
            .any((p) => p != null && (p - point).distance < _eraserSize));
      } else if (_currentPath != null) {
        _currentPath!.points.add(point);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDrawingMode) return;
    setState(() => _currentPath = null);
  }
  // --- END: Drawing Handlers ---
  
  Color? _parseColor(String? hex) {
      if (hex == null) return null;
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        return null;
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        elevation: 1,
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
      backgroundColor: Colors.grey.shade700,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _presentation == null || _presentation!.slides.isEmpty
                  ? const Center(
                      child: Text(
                        'No slides could be displayed from this file.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _presentation!.slides.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                              _saveCurrentPage(index);
                              _updateProgressOnServer(index + 1); // API is 1-based
                            },
                            itemBuilder: (context, index) {
                              final slide = _presentation!.slides[index];
                              final slideSize = Size(
                                _presentation!.slideSize.width / 9525,
                                _presentation!.slideSize.height / 9525
                              );

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                                decoration: BoxDecoration(
                                   boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: slideSize.width,
                                    height: slideSize.height,
                                    child: Stack(
                                      children: [
                                        // Slide content
                                        Container(
                                          color: _parseColor(slide.background) ?? Colors.white,
                                          child: Stack(children: slide.children),
                                        ),
                                        // Drawing canvas
                                        IgnorePointer(
                                          ignoring: !_isDrawingMode,
                                          child: GestureDetector(
                                            onPanStart: (details) => _handlePanStart(details, slideSize),
                                            onPanUpdate: (details) => _handlePanUpdate(details, slideSize),
                                            onPanEnd: _handlePanEnd,
                                            child: CustomPaint(
                                              painter: DrawingPainter(paths: _drawings[index] ?? []),
                                              child: Container(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Speaker Notes Section
                        if (_presentation!.slides[_currentPage].notes.isNotEmpty)
                          Expanded(
                            flex: 1,
                            child: Container(
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              padding: const EdgeInsets.all(16.0),
                              margin: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Speaker Notes:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    ..._presentation!.slides[_currentPage].notes,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_presentation!.slides.length > 1)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Slide ${_currentPage + 1} of ${_presentation!.slides.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                subtitle: Text('Font size cannot be changed for PPTX files.'),
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
            ],
          ),
        );
      },
    );
  }
}
