import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'document_model.dart';
import 'docx_parser.dart';

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


class WordDocViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int userId;
  final int fileId;

  const WordDocViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
    this.userId = 0, // Default value
    this.fileId = 0, // Default value
  }) : super(key: key);

  @override
  State<WordDocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<WordDocViewerScreen> {
  DocxDocument? _document;
  bool _isLoading = true;
  String _error = '';

  List<List<Widget>> _pages = [];
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
    // Restore default orientation
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

      final parser = DocxParser(archive);
      final document = await parser.parseDocument();
      
      _paginateDocument(document);
      
      // Load last visited page after pagination
      if (_pages.isNotEmpty) {
        await _loadProgressFromServer();
      }


      if (mounted) {
        setState(() {
          _document = document;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      if (mounted) {
        String errorMessage = "Failed to read document: ${e.toString()}\n$s";
        if (e is ArchiveException ||
            widget.fileName.toLowerCase().endsWith('.doc')) {
          errorMessage =
              "Failed to open file. This viewer supports modern .docx files only. The older .doc binary format is not supported.";
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  void _paginateDocument(DocxDocument document) {
    List<Widget> allContent = [];
    if (document.headers.isNotEmpty) {
      allContent.addAll(document.headers);
      allContent.add(const Divider(height: 48, thickness: 1));
    }
    allContent.addAll(document.body);
    if (document.footers.isNotEmpty) {
      allContent.add(const Divider(height: 48, thickness: 1));
      allContent.addAll(document.footers);
    }

    if (allContent.isEmpty) {
      setState(() {
        _pages = [];
      });
      return;
    }
    
    const double maxPageWeight = 22.0; 
    List<List<Widget>> pages = [];
    List<Widget> currentPageWidgets = [];
    double currentPageWeight = 0;

    double getWidgetWeight(Widget widget) {
      if (widget is Table) {
        return maxPageWeight + (widget.children.length * 2.0);
      }
      if (widget is Divider) return 1.0;
      if (widget is Padding) {
        final child = widget.child;
        if (child is RichText) {
          double weight = 0;
          final textSpan = child.text as TextSpan;
          
          int length = textSpan.toPlainText().length;
          weight += (length / 120.0).ceilToDouble();

          if (textSpan.children != null) {
            for (final span in textSpan.children!) {
              if (span is WidgetSpan) weight += 15.0; 
            }
          }
          return weight < 1.0 ? 1.0 : weight;
        }
        return 1.0;
      }
      return 2.0; 
    }

    for (int i=0; i < allContent.length; i++) {
      final widget = allContent[i];
      final widgetWeight = getWidgetWeight(widget);

      bool isLargeItem = widget is Table || widgetWeight > maxPageWeight * 0.8;

      if (isLargeItem && currentPageWidgets.isNotEmpty) {
        pages.add(List.from(currentPageWidgets));
        currentPageWidgets = [widget];
        currentPageWeight = widgetWeight;
        continue; 
      }
      
      if (currentPageWeight + widgetWeight > maxPageWeight && currentPageWidgets.isNotEmpty) {
        pages.add(List.from(currentPageWidgets));
        currentPageWidgets = [widget];
        currentPageWeight = widgetWeight;
      } else {
        currentPageWidgets.add(widget);
        currentPageWeight += widgetWeight;
      }
    }

    if (currentPageWidgets.isNotEmpty) {
      pages.add(List.from(currentPageWidgets));
    }
    
    setState(() {
      _pages = pages;
    });
  }


  Future<void> _saveCurrentPage(int pageIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_page_docx_${widget.filePath}', pageIndex);
    } catch (e) {
      debugPrint("Failed to save page progress: $e");
    }
  }

  Future<void> _loadProgressFromServer() async {
    if (widget.userId == 0 || widget.fileId == 0) {
      await _loadLastPageFromLocal();
      return;
    }

    try {
      final uri = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['currentPage'] != null) {
          final serverPage = data['currentPage'] as int;
          if (serverPage < _pages.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(serverPage);
                setState(() => _currentPage = serverPage);
              }
            });
            return;
          }
        }
      }
      await _loadLastPageFromLocal();
    } catch (e) {
      debugPrint("Server progress fetch failed, trying local: $e");
      await _loadLastPageFromLocal();
    }
  }

  void _updateProgressOnServer(int pageIndex) async {
    if (widget.userId == 0 || widget.fileId == 0) return;
    try {
      await http.post(
        Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/Bridge/UpdateFileReadingStatus'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': widget.userId,
          'fileId': widget.fileId,
          'currentPage': pageIndex,
        }),
      );
    } catch (e) {
      debugPrint("Server progress update failed: $e");
    }
  }

  Future<void> _loadLastPageFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('last_page_docx_${widget.filePath}');
      if (savedPage != null && savedPage < _pages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedPage);
            setState(() {
              _currentPage = savedPage;
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load saved page progress: $e");
    }
  }

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

  // --- END: Features from EPUB Viewer ---


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
            onPressed: () {
              setState(() {
                if (_isDrawingMode && !_isErasing) {
                  _isDrawingMode = false;
                } else {
                  _isDrawingMode = true;
                  _isErasing = false;
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services, color: _isDrawingMode && _isErasing ? Colors.blue : null),
            tooltip: 'Eraser',
            onPressed: () {
              setState(() {
                if (_isDrawingMode && _isErasing) {
                  _isDrawingMode = false;
                } else {
                  _isDrawingMode = true;
                  _isErasing = true;
                }
              });
            },
          ),
           IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsBottomSheet(context),
            ),
        ],
      ),
      backgroundColor: Colors.white,
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
              : _document == null || _pages.isEmpty
                  ? const Center(
                      child: Text(
                        'Is file se koi content display nahi kiya ja sakta.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            physics: _isDrawingMode ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                            itemCount: _pages.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                                _isDrawingMode = false;
                                _isErasing = false;
                              });
                              _saveCurrentPage(index);
                              _updateProgressOnServer(index);
                            },
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: EdgeInsets.zero,
                                    padding: const EdgeInsets.all(24.0),
                                    color: Colors.white,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: _pages[index],
                                      ),
                                    ),
                                  ),
                                  // Drawing Canvas
                                  IgnorePointer(
                                    ignoring: !_isDrawingMode,
                                    child: GestureDetector(
                                      onPanStart: _handlePanStart,
                                      onPanUpdate: _handlePanUpdate,
                                      onPanEnd: _handlePanEnd,
                                      child: CustomPaint(
                                        painter: DrawingPainter(paths: _drawings[index] ?? []),
                                        child: Container(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_pages.length > 1)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Page ${_currentPage + 1} of ${_pages.length}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text('Font Size Not Available'),
                    subtitle: const Text('Font size cannot be changed for DOCX files.'),
                    onTap: () => Navigator.pop(context),
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
      },
    );
  }
}