import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;
import 'package:csslib/parser.dart' as cssparser;
import 'package:csslib/visitor.dart' hide MediaQuery;
import 'package:html/dom.dart' as dom;
import 'package:flutter/foundation.dart';
import 'package:bridge/projects/viewers/search_screen.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bridge/Server/server_url.dart';

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

class EpubViewerScreenCopy extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int userId;
  final int fileId;

  const EpubViewerScreenCopy({
    Key? key,
    required this.filePath,
    required this.fileName,
    required this.userId,
    required this.fileId,
  }) : super(key: key);

  @override
  State<EpubViewerScreenCopy> createState() => _EpubViewerScreenCopyState();
}

class _EpubViewerScreenCopyState extends State<EpubViewerScreenCopy> {
  bool _loading = true;
  EpubBook? _book;
  bool _isFixedLayout = false;
  double _fontSize = 14.0;

  Map<String, Uint8List> _images = {};
  final Map<String, Map<String, String>> _cssRules = {};

  int _currentChapter = 0;
  final PageController _pageController = PageController();
  late TransformationController _transformationController;
  bool _isZoomed = false;

  bool _isDrawingMode = false;
  bool _isErasing = false;
  final Map<int, List<DrawingPath>> _drawings = {};
  DrawingPath? _currentPath;
  Color _drawingColor = Colors.red;
  final double _strokeWidth = 3.0;
  final double _eraserSize = 20.0;

  /// Cleans the HTML content by removing unwanted tags and whitespace.
  String _cleanHtml(String html) {
    // 1. Remove multiple <br> tags and replace them with a single one.
    html = html.replaceAll(
      RegExp(r'(<br\s*\/?>\s*){2,}', caseSensitive: false),
      '<br>',
    );

    // 2. Remove empty <p> tags that only contain whitespace or &nbsp;
    html = html.replaceAll(
      RegExp(r'<p[^>]*>(\s|&nbsp;)*<\/p>', caseSensitive: false),
      '',
    );

    // 3. Remove whitespace between tags to prevent unwanted space rendering.
    html = html.replaceAll(RegExp(r'>\s+<', caseSensitive: false), '><');

    return html.trim();
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onScaleChanged);
    _loadBook();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _pageController.dispose();
    _transformationController.removeListener(_onScaleChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onScaleChanged() {
    final isCurrentlyZoomed =
        _transformationController.value.getMaxScaleOnAxis() > 1.0;
    if (isCurrentlyZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isCurrentlyZoomed;
      });
    }
  }

  /// Parses all CSS content from the EPUB book and stores the rules.
  void _parseCssFromBook() {
    if (_isFixedLayout) {
      return;
    }
    if (_book?.Content?.Css == null || _book!.Content!.Css!.isEmpty) {
      return;
    }

    final allCssContent = _book!.Content!.Css!.values
        .map((cssFile) => cssFile.Content)
        .join('\n');

    if (allCssContent.trim().isEmpty) {
      return;
    }

    try {
      final styleSheet = cssparser.parse(allCssContent, errors: []);
      final visitor = _CssVisitor(
        onRule: (selector, declarations) {
          final cleanSelector = selector.split('{').first.trim();
          if (_cssRules.containsKey(cleanSelector)) {
            _cssRules[cleanSelector]!.addAll(declarations);
          } else {
            _cssRules[cleanSelector] = declarations;
          }
        },
      );
      styleSheet.visit(visitor);
    } catch (e) {
      // In a real app, you might want to log this error.
      debugPrint("Failed to parse CSS: $e");
    }
  }

  /// Loads the EPUB book from the file path provided.
  // Future<void> _loadBook() async {
  //   try {
  //     final file = File(widget.filePath);
  //     final bytes = await file.readAsBytes();
  //     final book = await EpubReader.readBook(bytes);

  //     final images = <String, Uint8List>{};
  //     book.Content?.Images?.forEach((key, value) {
  //       if (value.Content != null) {
  //         images[key] = Uint8List.fromList(value.Content!);
  //       }
  //     });

  //     if (!mounted) return;

  //     setState(() {
  //       _book = book;
  //       _images = images;
  //       _parseCssFromBook();
  //     });
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text("Failed to open EPUB: $e")));
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _loading = false);
  //     }
  //   }
  // }
  /// Loads the EPUB book from the file path provided, with a definitive fallback logic
  /// that compares chapter count with the book's spine.

  Future<void> _saveCurrentPage(int pageIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_page_${widget.filePath}', pageIndex);
    } catch (e) {
      debugPrint("Failed to save page progress: $e");
    }
  }

  Future<void> _loadProgressFromServer() async {
    if (_book == null) return;
    try {
      final uri = Uri.parse(
        '${baseUrl}bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['currentPage'] != null) {
          final serverPage = data['currentPage'] as int;
          if (_book != null && serverPage < _book!.Chapters!.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(serverPage);
                setState(() => _currentChapter = serverPage);
              }
            });
            return;
          }
        }
      }

      await _loadLastPage();
    } catch (e) {
      debugPrint(
        "Server se progress fetch nahi hua, local se try kar rahe hain: $e",
      );
      await _loadLastPage();
    }
  }

  void _updateProgressOnServer(int pageIndex) async {
  try {
    final response = await http.post(
      Uri.parse('${baseUrl}Bridge/UpdateFileReadingStatus'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'uid': widget.userId,
        'fileId': widget.fileId,
        'currentPage': pageIndex,
      }),
    );
    // if (response.statusCode == 200) {
      // final success = json.decode(response.body);
      // if (success == true) {
      //   debugPrint('Progress for fileId ${widget.fileId} saved on server.');
      // }
    // }

  } catch (e) {
    // debugPrint("Server par progress update nahi hua: $e");
  }
}

  Future<void> _loadLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('last_page_${widget.filePath}');
      if (savedPage != null &&
          _book != null &&
          savedPage < _book!.Chapters!.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedPage);
            setState(() {
              _currentChapter = savedPage;
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load saved page progress: $e");
    }
  }

  Future<void> _loadBook() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      EpubBook book = await EpubReader.readBook(bytes);

      final spineItems = book.Schema?.Package?.Spine?.Items;
      final manifestItems = book.Schema?.Package?.Manifest?.Items;
      final htmlFiles = book.Content?.Html;

      if (spineItems != null &&
          (book.Chapters == null ||
              book.Chapters!.length < spineItems.length)) {
        debugPrint(
          "TOC is incomplete. Rebuilding chapters from spine. Spine items: ${spineItems.length}, Parsed chapters: ${book.Chapters?.length ?? 0}",
        );

        if (manifestItems != null && htmlFiles != null) {
          final newChapters = <EpubChapter>[];

          for (final spineItem in spineItems) {
            final manifestItem = manifestItems.firstWhere(
              (item) => item.Id == spineItem.IdRef,
              orElse: () => EpubManifestItem(),
            );

            if (manifestItem.Href != null &&
                htmlFiles.containsKey(manifestItem.Href)) {
              final htmlFile = htmlFiles[manifestItem.Href!];
              newChapters.add(
                EpubChapter()
                  ..Title = manifestItem.Href!
                      .split('/')
                      .last
                      .replaceAll(
                        RegExp(r'\.x?html$', caseSensitive: false),
                        '',
                      )
                  ..ContentFileName = manifestItem.Href
                  ..HtmlContent = htmlFile?.Content,
              );
            }
          }

          if (newChapters.isNotEmpty) {
            book.Chapters = newChapters;
          }
        }
      }
      bool isFixedLayout = false;
      if (book.Content?.Html != null) {
        for (final htmlFile in book.Content!.Html!.values) {
          if (htmlFile.Content != null &&
              htmlFile.Content!.contains('<meta name="viewport"')) {
            isFixedLayout = true;
            debugPrint("Fixed-layout EPUB detected.");
            break; // Found it, no need to check other files.
          }
        }
      }

      final images = <String, Uint8List>{};
      book.Content?.Images?.forEach((key, value) {
        if (value.Content != null) {
          images[key] = Uint8List.fromList(value.Content!);
        }
      });

      if (!mounted) return;

      setState(() {
        _book = book;
        _images = images;
        _isFixedLayout = isFixedLayout;
        _parseCssFromBook();
      });
      // await _loadLastPage();
      await _loadProgressFromServer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to open EPUB: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Finds image data by its path, resolving relative paths if necessary.
  Uint8List? _findImageData(String imagePath, String? chapterPath) {
    final decodedPath = Uri.decodeComponent(imagePath);
    if (_images.containsKey(decodedPath)) return _images[decodedPath];

    if (chapterPath != null) {
      try {
        final resolvedPath = p.url.normalize(
          p.url.join(p.url.dirname(chapterPath), decodedPath),
        );
        if (_images.containsKey(resolvedPath)) return _images[resolvedPath];
      } catch (_) {
        // Path resolution can fail, ignore.
      }
    }

    final imageName = p.basename(decodedPath);
    for (final key in _images.keys) {
      if (p.basename(key) == imageName) return _images[key];
    }
    return null;
  }

  /// Replaces image URLs in HTML with base64-encoded data URIs.
  String _embedImagesInHtml(String htmlContent, String? chapterPath) {
    final regex = RegExp(
      r'''(<img[^>]*src\s*=\s*|<image[^>]*xlink:href\s*=\s*)"([^"]+)"''',
      caseSensitive: false,
    );
    return htmlContent.replaceAllMapped(regex, (match) {
      final tagPart = match.group(1)!;
      final imagePath = match.group(2)!;
      final imageData = _findImageData(imagePath, chapterPath);
      if (imageData != null) {
        final base64String = base64Encode(imageData);
        final mimeType = _getMimeType(imagePath);
        return '$tagPart"data:$mimeType;base64,$base64String"';
      }
      return match.input.substring(match.start, match.end);
    });
  }

  /// Determines the MIME type of an image from its file extension.
  String _getMimeType(String filename) {
    final extension = p.extension(filename).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.svg':
        return 'image/svg+xml';
      default:
        return 'image/jpeg';
    }
  }

  /// Formats a CSS color value into a format Flutter can understand.
  String _formatColorValue(String cssColor) {
    final lowerCssColor = cssColor.toLowerCase().trim();
    const colorMap = {
      'black': '#000000',
      'silver': '#C0C0C0',
      'gray': '#808080',
      'white': '#FFFFFF',
      'maroon': '#800000',
      'red': '#FF0000',
      'purple': '#800080',
      'fuchsia': '#FF00FF',
      'green': '#008000',
      'lime': '#00FF00',
      'olive': '#808000',
      'yellow': '#FFFF00',
      'navy': '#000080',
      'blue': '#0000FF',
      'teal': '#008080',
      'aqua': '#00FFFF',
      'transparent': 'transparent',
    };
    if (RegExp(
      r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$',
    ).hasMatch(lowerCssColor))
      return lowerCssColor;
    if (lowerCssColor.startsWith('rgb') || lowerCssColor.startsWith('hsl'))
      return lowerCssColor
          .replaceAll(RegExp(r'\s*,\s*'), ',')
          .replaceAll(RegExp(r'\s+'), ' ');
    if (colorMap.containsKey(lowerCssColor)) return colorMap[lowerCssColor]!;
    if (RegExp(r'^([0-9a-f]{3}|[0-9a-f]{6})$').hasMatch(lowerCssColor))
      return '#$lowerCssColor';
    return cssColor;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_isDrawingMode) return;

    // final box = context.findRenderObject() as RenderBox;
    // final point = box.globalToLocal(details.globalPosition);
    final point = details.localPosition;

    setState(() {
      if (_isErasing) {
        // Erase existing paths
        _drawings[_currentChapter]?.removeWhere((path) {
          return path.points.any(
            (p) => p != null && (p - point).distance < _eraserSize,
          );
        });
      } else {
        // Start a new path
        _currentPath = DrawingPath(
          points: [point],
          color: _drawingColor,
          strokeWidth: _strokeWidth,
        );
        if (_drawings[_currentChapter] == null) {
          _drawings[_currentChapter] = [];
        }
        _drawings[_currentChapter]!.add(_currentPath!);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode) return;

    // final box = context.findRenderObject() as RenderBox;
    // final point = box.globalToLocal(details.globalPosition);
    final point = details.localPosition;

    setState(() {
      if (_isErasing) {
        _drawings[_currentChapter]?.removeWhere((path) {
          return path.points.any(
            (p) => p != null && (p - point).distance < _eraserSize,
          );
        });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null || _book!.Chapters!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(
          child: Text("Book could not be loaded or is empty."),
        ),
      );
    }

    // const double baseFontSize = 14.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.Title ?? widget.fileName),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: _isDrawingMode && !_isErasing ? Colors.blue : null,
            ),
            tooltip: 'Draw',
            onPressed: () {
              setState(() {
                if (_isDrawingMode && !_isErasing) {
                  _isDrawingMode = false;
                  _drawings[_currentChapter]?.clear();
                } else {
                  _isDrawingMode = true;
                  _isErasing = false;
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _isDrawingMode && _isErasing ? Colors.blue : null,
            ),
            tooltip: 'Eraser',
            onPressed: () {
              setState(() {
                if (_isDrawingMode && _isErasing) {
                  _isDrawingMode = false;
                  _isErasing = false;
                } else {
                  _isDrawingMode = true;
                  _isErasing = true;
                }
              });
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Chapters',
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView.builder(
          itemCount: _book!.Chapters!.length,
          itemBuilder: (context, index) {
            final chapter = _book!.Chapters![index];
            return ListTile(
              title: Text(chapter.Title ?? 'Chapter ${index + 1}'),
              selected: index == _currentChapter,
              onTap: () {
                _pageController.jumpToPage(index);
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: _isDrawingMode
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              // physics: _isZoomed
              //     ? const NeverScrollableScrollPhysics()
              //     : const PageScrollPhysics(),
              itemCount: _book!.Chapters!.length,
              onPageChanged: (index) {
                setState(() {
                  _currentChapter = index;
                  _isDrawingMode = false;
                  _isErasing = false;
                });
                _transformationController.value = Matrix4.identity();
                _saveCurrentPage(index);
                _updateProgressOnServer(index);
              },
              itemBuilder: (context, index) {
                final chapter = _book!.Chapters![index];
                String htmlContent = chapter.HtmlContent ?? '';

                final chapterTitle = chapter.Title?.trim().toLowerCase() ?? '';
                if (htmlContent.isNotEmpty && chapterTitle.isNotEmpty) {
                  try {
                    var document = dom.Document.html(htmlContent);
                    final potentialTitles = document.querySelectorAll(
                      'h1, h2, h3, h4, h5, h6, p',
                    );
                    for (var element in potentialTitles) {
                      if (element.text.trim().toLowerCase() == chapterTitle) {
                        element.remove();
                        break;
                      }
                    }
                    htmlContent = document.body?.innerHtml ?? htmlContent;
                  } catch (e) {
                    // Ignore parsing errors for title removal
                  }
                }
                final cleanedHtml = _cleanHtml(htmlContent);

                final processedHtml = _embedImagesInHtml(
                  // htmlContent,
                  cleanedHtml,
                  chapter.ContentFileName,
                );

                // return SingleChildScrollView(
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: SingleChildScrollView(
                        // physics: _isZoomed
                        //     ? const NeverScrollableScrollPhysics()
                        //     : const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16.0,
                          16.0,
                          16.0,
                          55.0,
                        ),
                        child: HtmlWidget(
                          processedHtml,
                          textStyle: TextStyle(
                            fontSize:
                                _fontSize, // Naya variable istemaal karein
                            height: 1.5,
                            color: const Color(0xFF5D4037),
                          ),
                          customStylesBuilder: (element) {
                            if (element.localName == 'p' &&
                                element.text.trim().isEmpty &&
                                !element.innerHtml.contains('<img')) {
                              return {
                                'height': '0',
                                'margin': '0',
                                'padding': '0',
                              };
                            }
                            final appliedStyles = <String, String>{};

                            // Apply styles based on specificity
                            if (_cssRules.containsKey('*'))
                              appliedStyles.addAll(_cssRules['*']!);
                            if (_cssRules.containsKey(element.localName))
                              appliedStyles.addAll(
                                _cssRules[element.localName]!,
                              );
                            for (final className in element.classes) {
                              final classSelector = '.$className';
                              if (_cssRules.containsKey(classSelector))
                                appliedStyles.addAll(_cssRules[classSelector]!);
                              final tagAndClassSelector =
                                  '${element.localName}$classSelector';
                              if (_cssRules.containsKey(tagAndClassSelector))
                                appliedStyles.addAll(
                                  _cssRules[tagAndClassSelector]!,
                                );
                            }
                            if (element.id.isNotEmpty) {
                              final idSelector = '#${element.id}';
                              if (_cssRules.containsKey(idSelector))
                                appliedStyles.addAll(_cssRules[idSelector]!);
                            }

                            // Heuristics for centering
                            if ([
                                  'h1',
                                  'h2',
                                  'h3',
                                  'h4',
                                  'h5',
                                  'h6',
                                ].contains(element.localName) ||
                                element.classes.any(
                                  (c) => c.contains('center'),
                                )) {
                              appliedStyles['text-align'] = 'center';
                            }
                            if (element.localName == 'span') {
                              appliedStyles['text-align'] = 'center';
                            }
                            if (element.localName == 'p') {
                              appliedStyles['text-align'] = 'center';
                            }
                            if (element.localName == 'p' &&
                                element.text.trim().isEmpty &&
                                element.innerHtml.contains('<img')) {
                              appliedStyles['text-align'] = 'center';
                              appliedStyles['margin'] = '0';
                            }
                            if (element.localName == 'div' &&
                                element.children.length == 1 &&
                                (element.children.first.localName == 'svg' ||
                                    element.children.first.localName ==
                                        'img')) {
                              appliedStyles['text-align'] = 'center';
                            }

                            if (appliedStyles.isEmpty) return null;

                            final finalStyles = <String, String>{};
                            final isImage = [
                              'img',
                              'svg',
                              'image',
                            ].contains(element.localName);

                            appliedStyles.forEach((key, value) {
                              final cleanValue = value
                                  .replaceAll('+', '')
                                  .trim();
                              if (cleanValue.isEmpty) return;
                              if (isImage) {
                                switch (key) {
                                  case 'width':
                                  case 'height':
                                  case 'max-width':
                                  case 'max-height':
                                  case 'margin':
                                  case 'padding':
                                  case 'border':
                                    finalStyles[key] = cleanValue;
                                    break;
                                }
                                return;
                              }

                              switch (key) {
                                // case 'font-size':
                                //   String finalSize;
                                //   // If value already has a unit, pass it through. Otherwise, apply a heuristic.
                                //   if (RegExp(r'(px|%|em|rem|pt|pc|in|cm|mm)$', caseSensitive: false).hasMatch(cleanValue)) {
                                //     finalSize = cleanValue;
                                //   } else {
                                //     final numericValue = double.tryParse(cleanValue);
                                //     if (numericValue != null) {
                                //       // Heuristic: Small numbers (likely 'em'), large numbers (likely '%').
                                //       if (numericValue < 10) {
                                //         finalSize = '${numericValue}em';
                                //       } else {
                                //         finalSize = '${numericValue}%';
                                //       }
                                //     } else {
                                //       finalSize = cleanValue;
                                //     }
                                //   }
                                //   finalStyles[key] = finalSize;
                                //   break;
                                // case 'font-size':
                                //   finalStyles[key] = normalizeCssFontSize(cleanValue);
                                //   break;

                                case 'font-size':
                                  finalStyles[key] = cleanValue;
                                  break;

                                case 'line-height':
                                  String finalHeight;
                                  final numericValue = double.tryParse(
                                    cleanValue,
                                  );
                                  if (numericValue != null) {
                                    if (numericValue > 10) {
                                      finalHeight = (numericValue / 100)
                                          .toString();
                                    } else {
                                      finalHeight = numericValue.toString();
                                    }
                                  } else {
                                    finalHeight = cleanValue;
                                  }
                                  finalStyles[key] = finalHeight;
                                  break;

                                // case 'margin':
                                // case 'margin-top':
                                // case 'margin-bottom':
                                // case 'margin-left':
                                // case 'margin-right':
                                // case 'padding':
                                // case 'padding-top':
                                // case 'padding-bottom':
                                // case 'padding-left':
                                // case 'padding-right':
                                // case 'text-indent':
                                //   String finalValue;
                                //   if (cleanValue.toLowerCase().endsWith('px') ||
                                //       cleanValue.toLowerCase().endsWith('%')) {
                                //     finalValue = cleanValue;
                                //   } else {
                                //     final numericValue = double.tryParse(
                                //       cleanValue.replaceAll(
                                //         RegExp(r'em', caseSensitive: false),
                                //         '',
                                //       ),
                                //     );
                                //     if (numericValue != null) {
                                //       final newSize = numericValue * baseFontSize;
                                //       finalValue = '${newSize}px';
                                //     } else {
                                //       finalValue = cleanValue;
                                //     }
                                //   }
                                //   finalStyles[key] = finalValue;
                                //   break;

                                case 'color':
                                case 'background-color':
                                  finalStyles[key] = _formatColorValue(
                                    cleanValue,
                                  );
                                  break;

                                default:
                                  finalStyles[key] = cleanValue;
                                  break;
                              }
                            });

                            return finalStyles.isNotEmpty ? finalStyles : null;
                          },
                        ),
                      ),
                    ),

                    IgnorePointer(
                      ignoring: !_isDrawingMode,
                      child: GestureDetector(
                        onPanStart: _handlePanStart,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _handlePanEnd,
                        child: CustomPaint(
                          painter: DrawingPainter(
                            paths: _drawings[index] ?? [],
                          ),
                          child:
                              Container(), // Required to make CustomPaint hit-testable
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        // height: 50,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        color: Theme.of(
                          context,
                        ).scaffoldBackgroundColor.withOpacity(0.95),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Text(
                                      _book!.Chapters![_currentChapter].Title ??
                                          '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14.0),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chapter ${_currentChapter + 1} of ${_book!.Chapters!.length}',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () {
                                _showSettingsBottomSheet(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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
            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  // Wrap widget ka istemaal karein taaki content fit ho jaaye
                  children: <Widget>[
                    // 1. FONT SIZE OPTION
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
                        // Sheet ka state update karein
                        setStateSheet(() {
                          _fontSize = value;
                        });
                        // Main screen ka state update karein
                        setState(() {});
                      },
                    ),
                    const Divider(),

                    // 2. SEARCH OPTION
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Search in Book'),
                      onTap: () async {
                        if (_book == null || _book!.Chapters!.isEmpty) return;

                        // SearchScreen par navigate karein aur result ka intezaar karein
                        final selectedChapter = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SearchScreen(chapters: _book!.Chapters!),
                          ),
                        );

                        // Agar user ne koi result select kiya hai, to us chapter par jump karein
                        if (selectedChapter != null && mounted) {
                          _pageController.jumpToPage(selectedChapter);
                        }
                      },
                    ),
                    const Divider(),

                    // 3. ROTATE OPTION
                    ListTile(
                      leading: const Icon(Icons.screen_rotation),
                      title: const Text('Rotate Screen'),
                      onTap: () {
                        final currentOrientation = MediaQuery.of(
                          context,
                        ).orientation;

                        // Agar portrait hai to landscape karein, warna portrait karein
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
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  //   String normalizeCssFontSize(String cleanValue) {
  //     const double baseFontSize = 16.0;
  //     double finalFontSize = 14.0; // default

  //     final sizeRegex = RegExp(
  //       r'^([0-9.]+)(px|em|rem|%|pt|pc|in|cm|mm)?$',
  //       caseSensitive: false,
  //     );
  //     final match = sizeRegex.firstMatch(cleanValue);

  //     if (match != null) {
  //       final numericValue = double.tryParse(match.group(1)!);
  //       final unit = (match.group(2) ?? 'px').toLowerCase();

  //       if (numericValue != null) {
  //         switch (unit) {
  //           case 'px':
  //             finalFontSize = numericValue;
  //             break;
  //           case 'em':
  //           case 'rem':
  //             finalFontSize = numericValue * baseFontSize;
  //             break;
  //           case '%':
  //             finalFontSize = baseFontSize * (numericValue / 100);
  //             break;
  //           case 'pt':
  //             finalFontSize = numericValue * 1.333;
  //             break;
  //           case 'pc':
  //             finalFontSize = numericValue * 16.0;
  //             break;
  //           case 'in':
  //             finalFontSize = numericValue * 96.0;
  //             break;
  //           case 'cm':
  //             finalFontSize = numericValue * 37.8;
  //             break;
  //           case 'mm':
  //             finalFontSize = numericValue * 3.78;
  //             break;
  //           default:
  //             finalFontSize = numericValue;
  //         }
  //       }
  //     }

  //     return finalFontSize.toString();
  //   }
}

class _CssVisitor extends Visitor {
  final Function(String selector, Map<String, String> declarations) onRule;
  _CssVisitor({required this.onRule});

  String _expressionToText(Expression expr) {
    final printer = StringBuffer();
    expr.visit(_CssPrinter(printer));
    return printer.toString().trim();
  }

  @override
  void visitRuleSet(RuleSet node) {
    final selector =
        node.selectorGroup?.selectors
            .map((s) => s.span?.text ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ') ??
        '';

    final declarations = <String, String>{};
    for (var declaration in node.declarationGroup.declarations) {
      if (declaration is Declaration) {
        final property = declaration.property.toLowerCase();
        var value = '';
        if (declaration.expression != null) {
          value = _expressionToText(declaration.expression!);
        }
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        declarations[property] = value;
      }
    }

    if (selector.isNotEmpty && declarations.isNotEmpty) {
      final simpleSelectors = selector.split(',');
      for (var simpleSelector in simpleSelectors) {
        if (simpleSelector.trim().isNotEmpty) {
          onRule(simpleSelector.trim(), declarations);
        }
      }
    }
  }
}

class _CssPrinter extends Visitor {
  final StringBuffer buffer;
  _CssPrinter(this.buffer);

  @override
  void visitHexColorTerm(HexColorTerm node) => buffer.write(node.text);
  @override
  void visitLiteralTerm(LiteralTerm node) => buffer.write(node.text);
  @override
  void visitNumberTerm(NumberTerm node) => buffer.write(node.text);
  @override
  void visitPercentageTerm(PercentageTerm node) => buffer.write(node.text);
  @override
  void visitLengthTerm(LengthTerm node) => buffer.write(node.text);
  @override
  void visitEmTerm(EmTerm node) => buffer.write(node.text);
  @override
  void visitExTerm(ExTerm node) => buffer.write(node.text);
  @override
  void visitAngleTerm(AngleTerm node) => buffer.write(node.text);
  @override
  void visitTimeTerm(TimeTerm node) => buffer.write(node.text);
  @override
  void visitFreqTerm(FreqTerm node) => buffer.write(node.text);
  @override
  void visitUriTerm(UriTerm node) => buffer.write(node.text);

  @override
  void visitFunctionTerm(FunctionTerm node) {
    buffer.write('${node.text}(');
    for (int i = 0; i < node.params.length; i++) {
      node.params[i].visit(this);
      if (i < node.params.length - 1) {
        buffer.write(',');
      }
    }
    buffer.write(')');
  }
}
