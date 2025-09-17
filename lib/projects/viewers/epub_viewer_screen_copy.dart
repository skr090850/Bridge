import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;
import 'package:csslib/parser.dart' as cssparser;
import 'package:csslib/visitor.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBook();
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
      debugPrint("Failed to parse EPUB CSS: $e");
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
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to open EPUB: $e")));
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
      'navy': '#000080', 'blue': '#0000FF', 'teal': '#008080', 'aqua': '#00FFFF',
      'transparent': 'transparent',
    };
    if (RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$').hasMatch(lowerCssColor)) {
      return lowerCssColor;
    }
    if (lowerCssColor.startsWith('rgb') || lowerCssColor.startsWith('hsl')) {
      return lowerCssColor.replaceAll(RegExp(r'\s*,\s*'), ',').replaceAll(RegExp(r'\s+'), ' ');
    }
    if (colorMap.containsKey(lowerCssColor)) {
      return colorMap[lowerCssColor]!;
    }
    if (RegExp(r'^([0-9a-f]{3}|[0-9a-f]{6})$').hasMatch(lowerCssColor)) {
      return '#$lowerCssColor';
    }
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
    if (_book == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: Text("Book could not be loaded.")),
      );
    }
    
    const double baseFontSize = 18.0;

    return Scaffold(
      appBar: AppBar(title: Text(_book?.Title ?? widget.fileName)),
      body: PageView.builder(
        itemCount: _book?.Chapters?.length ?? 0,
        itemBuilder: (context, index) {
          final chapter = _book!.Chapters![index];
          final htmlContent = chapter.HtmlContent ?? "";
          final processedHtml = _embedImagesInHtml(
            htmlContent,
            chapter.ContentFileName,
          );

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: HtmlWidget(
                processedHtml,
                textStyle: const TextStyle(fontSize: baseFontSize),
                customStylesBuilder: (element) {
                  final appliedStyles = <String, String>{};

                  if (_cssRules.containsKey(element.localName)) {
                    appliedStyles.addAll(_cssRules[element.localName]!);
                  }
                  for (final className in element.classes) {
                    final classSelector = '.$className';
                    if (_cssRules.containsKey(classSelector)) {
                      appliedStyles.addAll(_cssRules[classSelector]!);
                    }
                    final tagAndClassSelector = '${element.localName}$classSelector';
                    if (_cssRules.containsKey(tagAndClassSelector)) {
                      appliedStyles.addAll(_cssRules[tagAndClassSelector]!);
                    }
                  }

                  if (element.attributes['align'] == 'center') {
                    appliedStyles['text-align'] = 'center';
                  }

                  if (element.localName == 'p') {
                      final containsRealText = element.nodes.any((node) => node is dom.Text && node.text.trim().isNotEmpty);
                      if (!containsRealText) {
                          bool hasImage = false;
                          void findImage(dom.Element el) {
                              if (['img', 'svg', 'image'].contains(el.localName)) {
                                  hasImage = true;
                                  return;
                              }
                              for (final child in el.children) {
                                  if (hasImage) break;
                                  findImage(child);
                              }
                          }
                          findImage(element);
                          if (hasImage) {
                              appliedStyles['text-align'] = 'center';
                          }
                      }
                  }

                  if (['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(element.localName)) {
                    appliedStyles['text-align'] = 'center';
                  }
                  
                  if (element.classes.any((c) => c.contains('center'))) {
                    appliedStyles['text-align'] = 'center';
                  }
                  
                  if (element.localName == 'div' &&
                      element.children.length == 1 &&
                      (element.children.first.localName == 'svg' ||
                          element.children.first.localName == 'img')) {
                    appliedStyles['text-align'] = 'center';
                  }

                  if (appliedStyles.isEmpty) return null;
                  
                  final finalStyles = <String, String>{};
                  final isImage = ['img', 'svg', 'image'].contains(element.localName);

                  appliedStyles.forEach((key, value) {
                    final cleanValue = value.replaceAll('+', '').trim();
                    if (cleanValue.isEmpty) return;
                    
                    if (isImage) {
                      const imageProps = ['width', 'height', 'max-width', 'max-height', 'min-width', 'min-height', 'margin', 'padding', 'border'];
                      if (imageProps.contains(key)){
                         finalStyles[key] = cleanValue;
                      }
                      return;
                    }
                    
                    switch (key) {
                      case 'font-size':
                        String finalSize;
                        if (cleanValue.toLowerCase().endsWith('px') || cleanValue.toLowerCase().endsWith('%')) {
                          finalSize = cleanValue;
                        } else {
                          final numericValue = double.tryParse(cleanValue.replaceAll(RegExp(r'[a-zA-Z]'),''));
                          if (numericValue != null) {
                             if (cleanValue.toLowerCase().contains('em')) {
                               finalSize = '${numericValue * baseFontSize}';
                             } else {
                               finalSize = cleanValue;
                             }
                          } else {
                            finalSize = cleanValue;
                          }
                        }
                        finalStyles[key] = finalSize;
                        break;

                      case 'line-height':
                        final numericValue = double.tryParse(cleanValue);
                        if (numericValue != null) {
                          finalStyles[key] = (numericValue > 10) ? (numericValue / 100).toString() : numericValue.toString();
                        } else {
                           finalStyles[key] = cleanValue;
                        }
                        break;

                      case 'margin':
                      case 'padding':
                      case 'text-indent':
                        String finalValue;
                        if (cleanValue.toLowerCase().endsWith('px') || cleanValue.toLowerCase().endsWith('%')) {
                          finalValue = cleanValue;
                        } else {
                           final numericValue = double.tryParse(cleanValue.replaceAll(RegExp(r'[a-zA-Z]'),''));
                           if(numericValue != null && cleanValue.toLowerCase().contains('em')){
                             finalValue = '${numericValue * baseFontSize}px';
                           } else {
                             finalValue = cleanValue;
                           }
                        }
                        finalStyles[key] = finalValue;
                        break;

                      case 'color':
                      case 'background-color':
                      case 'border-color':
                      case 'text-decoration-color':
                        finalStyles[key] = _formatColorValue(cleanValue);
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
          );
        },
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

