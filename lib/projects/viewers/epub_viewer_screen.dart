import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;

class EpubViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const EpubViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<EpubViewerScreen> createState() => _EpubViewerScreenState();
}

class _EpubViewerScreenState extends State<EpubViewerScreen> {
  bool _loading = true;
  EpubBook? _book;
  Map<String, Uint8List> _images = {};

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      final images = <String, Uint8List>{};
      if (book.Content?.Images != null) {
        book.Content!.Images!.forEach((key, value) {
          if (value.Content != null) {
            images[key] = Uint8List.fromList(value.Content!);
          }
        });
      }

      debugPrint('--- EPUB Loading Report ---');
      debugPrint('Total images loaded from EPUB: ${images.length}');
      if (images.isNotEmpty) {
        debugPrint('Available image keys (paths): ${images.keys.toList()}');
      }
      debugPrint('--- End of Report ---\n');

      if (!mounted) return;

      setState(() {
        _book = book;
        _images = images;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load EPUB: $e");
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed in open EPUB: $e")),
        );
      }
    }
  }
  Uint8List? _findImageData(String imagePath, String? chapterPath) {
    final decodedPath = Uri.decodeComponent(imagePath);

    if (_images.containsKey(decodedPath)) {
      return _images[decodedPath];
    }

    if (chapterPath != null) {
      try {
        final resolvedPath = p.url.normalize(
          p.url.join(p.url.dirname(chapterPath), decodedPath),
        );
        if (_images.containsKey(resolvedPath)) {
          return _images[resolvedPath];
        }
      } catch (_) {}
    }

    final imageName = p.basename(decodedPath);
    for (final key in _images.keys) {
      if (p.basename(key) == imageName) {
        return _images[key];
      }
    }
    
    return null;
  }

  String _embedImagesInHtml(String htmlContent, String? chapterPath) {
    final regex = RegExp(r'''(<img[^>]*src\s*=\s*|<image[^>]*xlink:href\s*=\s*)"([^"]+)"''', caseSensitive: false);
    
    return htmlContent.replaceAllMapped(regex, (match) {
      final tagPart = match.group(1)!;
      final imagePath = match.group(2)!;
      
      final imageData = _findImageData(imagePath, chapterPath);
      
      if (imageData != null) {
        final base64String = base64Encode(imageData);
        final mimeType = _getMimeType(imagePath);
        return '$tagPart"data:$mimeType;base64,$base64String"';
      } else {
        return match.input.substring(match.start, match.end);
      }
    });
  }

  String _getMimeType(String filename) {
    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (filename.endsWith('.png')) {
      return 'image/png';
    } else if (filename.endsWith('.gif')) {
      return 'image/gif';
    } else if (filename.endsWith('.svg')) {
      return 'image/svg+xml';
    }
    return 'image/jpeg';
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: Text("Book is not loaded")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.Title ?? widget.fileName),
      ),
      body: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _book?.Chapters?.length ?? 0,
        itemBuilder: (context, index) {
          final chapter = _book!.Chapters![index];
          final htmlContent = chapter.HtmlContent ?? "";
          
          final processedHtml = _embedImagesInHtml(htmlContent, chapter.ContentFileName);

          return SafeArea(
            child: Container(
              color: const Color(0xFFFBF0D9),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: HtmlWidget(
                  processedHtml, 
                  customStylesBuilder: (element) {
                    if (['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
                        .contains(element.localName)) {
                      return {'text-align': 'center'};
                    }
                    if (element.classes.any((c) => c.contains('center'))) {
                      return {'text-align': 'center'};
                    }
                    if (element.localName == 'div' &&
                        element.children.length == 1 &&
                        (element.children.first.localName == 'svg' ||
                            element.children.first.localName == 'img')) {
                      return {'text-align': 'center'};
                    }
                    return null;
                  },
                  textStyle: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}