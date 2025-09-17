import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;
import 'package:csslib/parser.dart' as cssparser;
import 'package:csslib/visitor.dart' hide MediaQuery;
import 'package:html/dom.dart' as dom;

class EpubViewerScreenCopy extends StatefulWidget {
  final String filePath;
  final String fileName;

  const EpubViewerScreenCopy({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<EpubViewerScreenCopy> createState() => _EpubViewerScreenCopyState();
}

class _EpubViewerScreenCopyState extends State<EpubViewerScreenCopy> {
  bool _loading = true;
  EpubBook? _book;
  Map<String, Uint8List> _images = {};
  final Map<String, Map<String, String>> _cssRules = {};

  int _currentChapter = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _parseCssFromBook() {
    if (_book?.Content?.Css == null || _book!.Content!.Css!.isEmpty) {
      return;
    }

    final allCssContent =
        _book!.Content!.Css!.values.map((cssFile) => cssFile.Content).join('\n');

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
      // In a real app, you might want to log this error
    }
  }

  Future<void> _loadBook() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

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
        _parseCssFromBook();
      });
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

  Uint8List? _findImageData(String imagePath, String? chapterPath) {
    final decodedPath = Uri.decodeComponent(imagePath);
    if (_images.containsKey(decodedPath)) return _images[decodedPath];

    if (chapterPath != null) {
      final resolvedPath = p.url.normalize(
        p.url.join(p.url.dirname(chapterPath), decodedPath),
      );
      if (_images.containsKey(resolvedPath)) return _images[resolvedPath];
    }

    final imageName = p.basename(decodedPath);
    for (final key in _images.keys) {
      if (p.basename(key) == imageName) return _images[key];
    }
    return null;
  }

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

  String _formatColorValue(String cssColor) {
    final lowerCssColor = cssColor.toLowerCase().trim();
    const colorMap = {
      'black': '#000000', 'silver': '#C0C0C0', 'gray': '#808080', 'white': '#FFFFFF',
      'maroon': '#800000', 'red': '#FF0000', 'purple': '#800080', 'fuchsia': '#FF00FF',
      'green': '#008000', 'lime': '#00FF00', 'olive': '#808000', 'yellow': '#FFFF00',
      'navy': '#008080', 'blue': '#0000FF', 'teal': '#008080', 'aqua': '#00FFFF',
      'transparent': 'transparent',
    };
    if (RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$').hasMatch(lowerCssColor)) return lowerCssColor;
    if (lowerCssColor.startsWith('rgb') || lowerCssColor.startsWith('hsl')) return lowerCssColor.replaceAll(RegExp(r'\s*,\s*'), ',').replaceAll(RegExp(r'\s+'), ' ');
    if (colorMap.containsKey(lowerCssColor)) return colorMap[lowerCssColor]!;
    if (RegExp(r'^([0-9a-f]{3}|[0-9a-f]{6})$').hasMatch(lowerCssColor)) return '#$lowerCssColor';
    return cssColor;
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
        body: const Center(child: Text("Book could not be loaded or is empty.")),
      );
    }

    const double baseFontSize = 18.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.Title ?? widget.fileName), // Title restored to show book title
        actions: [
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
                Navigator.of(context).pop(); // Close the drawer
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _book!.Chapters!.length,
            onPageChanged: (index) {
              setState(() => _currentChapter = index);
            },
            itemBuilder: (context, index) {
              final chapter = _book!.Chapters![index];
              String htmlContent = chapter.HtmlContent ?? '';

              // START: Remove in-page title from HTML content to avoid duplication
              final chapterTitle = chapter.Title?.trim().toLowerCase() ?? '';
              if (htmlContent.isNotEmpty && chapterTitle.isNotEmpty) {
                try {
                  var document = dom.Document.html(htmlContent);
                  // Check all heading tags. Sometimes titles can also be in <p> tags.
                  final potentialTitles = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p');
                  for (var element in potentialTitles) {
                    if (element.text.trim().toLowerCase() == chapterTitle) {
                       element.remove();
                       break; // Remove only the first occurrence.
                    }
                  }
                  // Use body's inner HTML to avoid including <html> and <body> tags
                  htmlContent = document.body?.innerHtml ?? htmlContent;
                } catch (e) {
                  // If parsing fails, just use the original content and log the error.
                  debugPrint("Error while removing title from chapter HTML: $e");
                }
              }
              // END: Remove in-page title

              final processedHtml = _embedImagesInHtml(htmlContent, chapter.ContentFileName);

              // Each page is a scrollable view of one chapter
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 60.0), // Padding for bottom bar
                child: HtmlWidget(
                  processedHtml,
                  textStyle: const TextStyle(fontSize: baseFontSize, height: 1.5),
                  customStylesBuilder: (element) {
                    // Title hiding logic has been moved to process the HTML string directly
                    // before rendering, for more reliability.

                    final appliedStyles = <String, String>{};

                    if (_cssRules.containsKey(element.localName)) appliedStyles.addAll(_cssRules[element.localName]!);
                    for (final className in element.classes) {
                      final classSelector = '.$className';
                      if (_cssRules.containsKey(classSelector)) appliedStyles.addAll(_cssRules[classSelector]!);
                      final tagAndClassSelector = '${element.localName}$classSelector';
                      if (_cssRules.containsKey(tagAndClassSelector)) appliedStyles.addAll(_cssRules[tagAndClassSelector]!);
                    }

                    if (element.attributes['align'] == 'center' || ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(element.localName) || element.classes.any((c) => c.contains('center'))) {
                      appliedStyles['text-align'] = 'center';
                    }
                    if (element.localName == 'p' && element.text.trim().isEmpty && element.innerHtml.contains('<img')) {
                      appliedStyles['text-align'] = 'center';
                    }

                    if (appliedStyles.isEmpty) return null;

                    final finalStyles = <String, String>{};
                    appliedStyles.forEach((key, value) {
                      final cleanValue = value.replaceAll('+', '').trim();
                      if (cleanValue.isEmpty) return;

                      switch (key) {
                        case 'color':
                        case 'background-color':
                          finalStyles[key] = _formatColorValue(cleanValue);
                          break;
                        default:
                          finalStyles[key] = cleanValue;
                          break;
                      }
                    });

                    return finalStyles.isNotEmpty ? finalStyles : null;
                  },
                  customWidgetBuilder: (element) {
                    if (element.localName == 'button') {
                      final onclick = element.attributes['onclick'];
                      if (onclick != null) {
                        // Regex to find href links in onclick attributes
                        final regex = RegExp(r'''location.href\s*=\s*['"]([^'"]+)['"]''');
                        final match = regex.firstMatch(onclick);

                        if (match != null) {
                          final targetFile = match.group(1)!;
                          final currentChapterPath = chapter.ContentFileName;

                          // Resolve path relative to current chapter directory
                          final resolvedPath = (currentChapterPath != null)
                              ? p.url.normalize(p.url.join(p.url.dirname(currentChapterPath), targetFile))
                              : targetFile;

                          // Find the index of the chapter that matches the resolved path
                          final targetChapterIndex = _book!.Chapters!.indexWhere((chap) => chap.ContentFileName == resolvedPath);

                          if (targetChapterIndex != -1) {
                            // Return a functional TextButton aligned to the right, without padding
                            return Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _pageController.jumpToPage(targetChapterIndex);
                                },
                                child: Text(element.text),
                              ),
                            );
                          }
                        }
                      }
                      // Fallback for non-navigational buttons or if chapter not found
                      return Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: null, // Disabled button
                          child: Text(element.text),
                        ),
                      );
                    }
                    return null; // Let the library handle other elements
                  },
                ),
              );
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _book!.Chapters![_currentChapter].Title ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chapter ${_currentChapter + 1} of ${_book!.Chapters!.length}',
                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- HELPER CLASSES FOR CSS PARSING ---
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
        node.selectorGroup?.selectors.map((s) => s.span?.text ?? '').where((s) => s.isNotEmpty).join(', ') ?? '';

    final declarations = <String, String>{};
    for (var declaration in node.declarationGroup.declarations) {
      if (declaration is Declaration) {
        final property = declaration.property.toLowerCase();
        var value = '';
        if (declaration.expression != null) {
          value = _expressionToText(declaration.expression!);
        }
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
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

