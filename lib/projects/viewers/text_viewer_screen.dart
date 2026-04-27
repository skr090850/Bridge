import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:bridge/Server/server_url.dart';

// Drawing classes
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

class TextViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int userId;
  final int fileId;

  const TextViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.userId = 0,
    this.fileId = 0,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  String _fileContent = '';
  bool _isLoading = true;
  double _fontSize = 16.0;
  final ScrollController _scrollController = ScrollController();

  // Drawing states
  bool _isDrawingMode = false;
  bool _isErasing = false;
  // For text files, we only need one drawing canvas as it's one long page
  List<DrawingPath> _drawings = [];
  DrawingPath? _currentPath;
  Color _drawingColor = Colors.red;
  final double _strokeWidth = 3.0;
  final double _eraserSize = 20.0;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndContent();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    _saveScrollPosition(_scrollController.offset);
    _updateProgressOnServer(_scrollController.offset);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndContent() async {
    await _loadFontSize();
    await _readFileContent();
    await _loadProgressFromServer();
  }

  Future<void> _readFileContent() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (mounted) setState(() => _fileContent = content);
    } catch (e) {
      if (mounted) setState(() => _fileContent = 'Error reading file: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // --- START: Settings and Progress Logic ---

  Future<void> _saveFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_text', _fontSize);
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _fontSize = prefs.getDouble('font_size_text') ?? 16.0);
  }

  Future<void> _saveScrollPosition(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scroll_pos_text_${widget.filePath}', offset);
  }

  Future<void> _loadProgressFromServer() async {
    if (widget.userId == 0 || widget.fileId == 0) {
      await _loadScrollPositionFromLocal();
      return;
    }
    try {
      final uri = Uri.parse('${baseUrl}bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['currentPage'] != null) {
          final serverPos = (data['currentPage'] as num).toDouble();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                 _scrollController.jumpTo(serverPos);
              }
            });
          return;
        }
      }
      await _loadScrollPositionFromLocal();
    } catch (e) {
      await _loadScrollPositionFromLocal();
    }
  }
  
  void _updateProgressOnServer(double offset) async {
    if (widget.userId == 0 || widget.fileId == 0) return;
    try {
      await http.post(
        Uri.parse('${baseUrl}Bridge/UpdateFileReadingStatus'),
        headers: {'Content-Type': 'application/json'},
        // Using currentPage to store scroll offset
        body: json.encode({'uid': widget.userId, 'fileId': widget.fileId, 'currentPage': offset.toInt()}),
      );
    } catch (e) {
      debugPrint("Server text progress update failed: $e");
    }
  }

  Future<void> _loadScrollPositionFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final position = prefs.getDouble('scroll_pos_text_${widget.filePath}');
    if (position != null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_scrollController.hasClients) {
            _scrollController.jumpTo(position);
         }
       });
    }
  }

  // --- END: Settings and Progress Logic ---
  
  // --- START: Drawing Handlers ---
  void _handlePanStart(DragStartDetails details) {
    if (!_isDrawingMode) return;
    final point = details.localPosition;
    setState(() {
      if (_isErasing) {
        _drawings.removeWhere((path) =>
            path.points.any((p) => p != null && (p - point).distance < _eraserSize));
      } else {
        _currentPath = DrawingPath(points: [point], color: _drawingColor, strokeWidth: _strokeWidth);
        _drawings.add(_currentPath!);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode) return;
    final point = details.localPosition;
    setState(() {
      if (_isErasing) {
        _drawings.removeWhere((path) =>
            path.points.any((p) => p != null && (p - point).distance < _eraserSize));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
           IconButton(
            icon: Icon(Icons.edit, color: _isDrawingMode && !_isErasing ? Colors.blue : null),
            onPressed: () => setState(() {
              _isDrawingMode = _isDrawingMode && !_isErasing ? false : true;
              _isErasing = false;
            }),
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services, color: _isDrawingMode && _isErasing ? Colors.blue : null),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
            children: [
              SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_fileContent, style: TextStyle(fontSize: _fontSize)),
                ),
              IgnorePointer(
                ignoring: !_isDrawingMode,
                child: GestureDetector(
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  child: CustomPaint(
                    painter: DrawingPainter(paths: _drawings),
                    child: Container(),
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
                  const ListTile(
                    leading: Icon(Icons.format_size),
                    title: Text('Font Size'),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 10.0,
                    max: 30.0,
                    divisions: 10,
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
