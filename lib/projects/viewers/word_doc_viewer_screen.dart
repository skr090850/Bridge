import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:typed_data';

// Helper class to hold styling information.
class DocxStyle {
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final String? color;
  final double? fontSize;
  final TextAlign? alignment;

  DocxStyle({
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.color,
    this.fontSize,
    this.alignment,
  });

  // Merges another style on top of this one. Properties from the `other` style take precedence.
  DocxStyle merge(DocxStyle? other) {
    if (other == null) return this;
    return DocxStyle(
      isBold: other.isBold ?? isBold,
      isItalic: other.isItalic ?? isItalic,
      isUnderline: other.isUnderline ?? isUnderline,
      color: other.color ?? color,
      fontSize: other.fontSize ?? fontSize,
      alignment: other.alignment ?? alignment,
    );
  }
}

class DocViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const DocViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  List<RichText> _documentContent = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAndParseDocument();
  }

  Future<void> _loadAndParseDocument() async {
    try {
      final widgets = await _parseDocx(widget.filePath);
      if (mounted) {
        setState(() {
          _documentContent = widgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = "Failed to read document: ${e.toString()}";
        if (e is ArchiveException || widget.fileName.toLowerCase().endsWith('.doc')) {
           errorMessage =
              "Failed to open file. This viewer supports .docx files, but not the older .doc format.";
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  /// Parses the .docx file and returns a list of RichText widgets.
  Future<List<RichText>> _parseDocx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File does not exist: $filePath");
    }
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final styles = _loadStyles(archive);
    final imagePaths = _loadImageRels(archive);

    final docxFile = archive.findFile('word/document.xml');
    if (docxFile == null) {
      throw Exception('word/document.xml not found in the archive.');
    }

    final docxContent =
        utf8.decode(docxFile.content as List<int>, allowMalformed: true);
    final documentXml = XmlDocument.parse(docxContent);
    final paragraphs = documentXml.findAllElements('w:p');

    List<RichText> widgets = [];
    for (final p in paragraphs) {
      final paragraphStyle = _parseParagraphStyle(p, styles);
      final inlineSpans = _processParagraphContent(p, archive, imagePaths, paragraphStyle, styles);

      if (inlineSpans.isNotEmpty) {
        widgets.add(
          RichText(
            textAlign: paragraphStyle.alignment ?? TextAlign.start,
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 16.0, height: 1.5),
              children: inlineSpans,
            ),
          ),
        );
      }
    }
    return widgets;
  }
  
  // --- Style and Relationship Loading ---

  Map<String, String> _loadImageRels(Archive archive) {
    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    final Map<String, String> imagePaths = {};
    if (relsFile != null) {
      final relsContent = utf8.decode(relsFile.content as List<int>);
      final relsDoc = XmlDocument.parse(relsContent);
      relsDoc.findAllElements('Relationship').forEach((node) {
        final id = node.getAttribute('Id');
        final target = node.getAttribute('Target');
        if (id != null && target != null && node.getAttribute('Type')?.endsWith('/image') == true) {
          imagePaths[id] = 'word/$target';
        }
      });
    }
    return imagePaths;
  }

  Map<String, DocxStyle> _loadStyles(Archive archive) {
    final stylesFile = archive.findFile('word/styles.xml');
    if (stylesFile == null) return {};

    final stylesContent = utf8.decode(stylesFile.content as List<int>);
    final stylesDoc = XmlDocument.parse(stylesContent);
    final Map<String, DocxStyle> styles = {};

    stylesDoc.findAllElements('w:style').forEach((node) {
      final styleId = node.getAttribute('w:styleId');
      if (styleId != null) {
        styles[styleId] = _parseStyle(node);
      }
    });
    return styles;
  }
  
  // --- XML Node Parsing ---

  List<InlineSpan> _processParagraphContent(
      XmlElement paragraph, Archive archive, Map<String, String> imagePaths, DocxStyle baseStyle, Map<String, DocxStyle> styles) {
    List<InlineSpan> spans = [];
    
    final runs = paragraph.findAllElements('w:r');
    for (final run in runs) {
      final drawingElement = run.findElements('w:drawing').firstOrNull ?? run.findElements('w:pict').firstOrNull;
      if (drawingElement != null) {
        final imageSpan = _processImage(drawingElement, archive, imagePaths);
        if (imageSpan != null) spans.add(imageSpan);
      } else {
        spans.add(_processTextRun(run, baseStyle));
      }
    }
    
    if (spans.isNotEmpty) {
      spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  TextSpan _processTextRun(XmlElement run, DocxStyle baseStyle) {
    final directStyle = _parseStyle(run);
    final finalStyle = baseStyle.merge(directStyle);
    
    final text = run.descendants.whereType<XmlText>().map((t) => t.text).join();

    return TextSpan(
      text: text,
      style: TextStyle(
        fontWeight: finalStyle.isBold == true ? FontWeight.bold : FontWeight.normal,
        fontStyle: finalStyle.isItalic == true ? FontStyle.italic : FontStyle.normal,
        decoration: finalStyle.isUnderline == true ? TextDecoration.underline : TextDecoration.none,
        color: _parseColor(finalStyle.color),
        fontSize: finalStyle.fontSize,
      ),
    );
  }

  WidgetSpan? _processImage(
      XmlElement drawingElement, Archive archive, Map<String, String> imagePaths) {
    String? embedId;
    final blipElement = drawingElement.findAllElements('a:blip').firstOrNull;
    if (blipElement != null) {
      embedId = blipElement.getAttribute('r:embed');
    } else {
      final imageDataElement = drawingElement.findAllElements('v:imagedata').firstOrNull;
      if (imageDataElement != null) embedId = imageDataElement.getAttribute('r:id');
    }

    if (embedId != null && imagePaths.containsKey(embedId)) {
      final imagePath = imagePaths[embedId]!;
      final imageFile = archive.findFile(imagePath);
      if (imageFile != null) {
        return WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.memory(imageFile.content as Uint8List),
          ),
        );
      }
    }
    return null;
  }

  DocxStyle _parseParagraphStyle(XmlElement p, Map<String, DocxStyle> styles) {
    final pPr = p.findElements('w:pPr').firstOrNull;
    if (pPr == null) return DocxStyle();

    final styleId = pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
    DocxStyle style = styles[styleId] ?? DocxStyle();

    final directStyle = _parseStyle(pPr);
    return style.merge(directStyle);
  }

  DocxStyle _parseStyle(XmlElement? element) {
    if (element == null) return DocxStyle();
    
    final rPr = element.findElements('w:rPr').firstOrNull ?? element;
    
    final isBold = rPr.findElements('w:b').isNotEmpty;
    final isItalic = rPr.findElements('w:i').isNotEmpty;
    final underlineNode = rPr.findElements('w:u').firstOrNull;
    final isUnderline = underlineNode != null && underlineNode.getAttribute('w:val') != 'none';
    
    final colorNode = rPr.findElements('w:color').firstOrNull;
    final color = colorNode?.getAttribute('w:val');
    
    final sizeNode = rPr.findElements('w:sz').firstOrNull;
    final fontSize = double.tryParse(sizeNode?.getAttribute('w:val') ?? '');
    
    // Check for paragraph alignment
    final pPr = element.name.local == 'w:pPr' ? element : null;
    final jcNode = pPr?.findElements('w:jc').firstOrNull;
    final alignmentVal = jcNode?.getAttribute('w:val');
    TextAlign? alignment;
    if (alignmentVal == 'center') alignment = TextAlign.center;
    if (alignmentVal == 'right') alignment = TextAlign.right;
    if (alignmentVal == 'both') alignment = TextAlign.justify;

    return DocxStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      color: color,
      fontSize: fontSize != null ? fontSize / 2 : null, // Font size is in half-points
      alignment: alignment,
    );
  }

  Color? _parseColor(String? colorValue) {
    if (colorValue == null || colorValue == 'auto') return Colors.black;
    try {
      return Color(int.parse('FF$colorValue', radix: 16));
    } catch (e) {
      return Colors.black;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
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
              : _documentContent.isEmpty
                  ? const Center(
                      child: Text(
                        'No content could be displayed from this file.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _documentContent.length,
                      itemBuilder: (context, index) {
                        return _documentContent[index];
                      },
                    ),
    );
  }
}

