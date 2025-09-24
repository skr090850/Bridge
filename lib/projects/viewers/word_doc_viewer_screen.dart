// Import necessary packages
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

/// Extension: Safely get the first element of an iterable or null.
extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ----------------------------------------------------
// ------------- DATA MODELS FOR STYLING --------------
// ----------------------------------------------------

class DocxStyle {
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final String? color;
  final String? cellColor;
  final double? fontSize;
  final TextAlign? alignment;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? indentLeft;
  final double? indentFirstLine;

  DocxStyle({
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.color,
    this.cellColor,
    this.fontSize,
    this.alignment,
    this.spacingBefore,
    this.spacingAfter,
    this.indentLeft,
    this.indentFirstLine,
  });

  /// Merges another style on top of this one. Properties from [other] take precedence.
  DocxStyle merge(DocxStyle? other) {
    if (other == null) return this;
    return DocxStyle(
      isBold: other.isBold ?? isBold,
      isItalic: other.isItalic ?? isItalic,
      isUnderline: other.isUnderline ?? isUnderline,
      color: other.color ?? color,
      cellColor: other.cellColor ?? cellColor,
      fontSize: other.fontSize ?? fontSize,
      alignment: other.alignment ?? alignment,
      spacingBefore: other.spacingBefore ?? spacingBefore,
      spacingAfter: other.spacingAfter ?? spacingAfter,
      indentLeft: other.indentLeft ?? indentLeft,
      indentFirstLine: other.indentFirstLine ?? indentFirstLine,
    );
  }
}

// ----------------------------------------------------
// --------------- NUMBERING MANAGER ------------------
// ----------------------------------------------------

/// Manages the definitions and state of numbered/bulleted lists.
class NumberingManager {
  // Stores the format of each numbering level (e.g., '1.', 'a.', '•')
  final Map<String, Map<String, String>> _definitions = {};
  // Stores the current counter for each numbering instance.
  final Map<String, int> _counters = {};

  NumberingManager(Archive archive) {
    final numFile = archive.findFile('word/numbering.xml');
    if (numFile == null) return;

    final numContent = utf8.decode(numFile.content as List<int>);
    final numDoc = XmlDocument.parse(numContent);

    // Parse numbering definitions
    for (final numElement in numDoc.findAllElements('w:num')) {
      final numId = numElement.getAttribute('w:numId');
      if (numId == null) continue;
      _definitions[numId] = {};

      for (final lvlElement in numElement.findAllElements('w:lvl')) {
        final ilvl = lvlElement.getAttribute('w:ilvl');
        final numFmt = lvlElement.findElements('w:numFmt').firstOrNull?.getAttribute('w:val');
        final lvlText = lvlElement.findElements('w:lvlText').firstOrNull?.getAttribute('w:val');
        
        if (ilvl != null && numFmt != null && lvlText != null) {
          String format;
          switch (numFmt) {
            case 'decimal':
              format = lvlText.replaceAll('%1', '{.}'); // Placeholder for number
              break;
            case 'bullet':
              format = lvlText;
              break;
            default:
              format = '•'; // Default bullet
          }
          _definitions[numId]![ilvl] = format;
        }
      }
    }
  }

  /// Gets the formatted string for a list item and updates the counter.
  String getBulletText(String numId, String level) {
    // Reset deeper level counters when a higher level is processed
    final currentLevel = int.tryParse(level) ?? 0;
    for (var i = currentLevel + 1; i < 10; i++) {
      _counters['${numId}_$i'] = 0;
    }

    // Increment the counter for the current level
    final key = '${numId}_$level';
    _counters[key] = (_counters[key] ?? 0) + 1;
    final count = _counters[key]!;

    // Get the format and replace the placeholder with the actual number
    final format = _definitions[numId]?[level] ?? '•';
    return format.replaceAll('{.}', '$count.');
  }
}


// ----------------------------------------------------
// ------------------ DOCX PARSER ---------------------
// ----------------------------------------------------

class DocxParser {
  final Archive _archive;
  final Map<String, DocxStyle> _styles = {};
  final Map<String, String> _imagePaths = {};
  final Map<String, String> _hyperlinkUrls = {};
  late final NumberingManager _numbering;

  DocxParser(this._archive) {
    _numbering = NumberingManager(_archive);
    _loadRelationships();
    _loadStyles();
  }

  Future<List<Widget>> parseDocument() async {
    final docxFile = _archive.findFile('word/document.xml');
    if (docxFile == null) throw Exception('word/document.xml not found.');

    final docxContent = utf8.decode(docxFile.content as List<int>, allowMalformed: true);
    final documentXml = XmlDocument.parse(docxContent);
    final body = documentXml.findAllElements('w:body').firstOrNull;
    if (body == null) return [];

    List<Widget> widgets = [];
    for (final element in body.children.whereType<XmlElement>()) {
      if (element.name.local == 'p') {
        final pWidget = _buildParagraphWidget(element);
        if (pWidget != null) widgets.add(pWidget);
      } else if (element.name.local == 'tbl') {
        final tWidget = _buildTableWidget(element);
        if (tWidget != null) widgets.add(tWidget);
      }
    }
    return widgets;
  }

  void _loadRelationships() {
    final relsFile = _archive.findFile('word/_rels/document.xml.rels');
    if (relsFile == null) return;

    final relsContent = utf8.decode(relsFile.content as List<int>);
    final relsDoc = XmlDocument.parse(relsContent);
    relsDoc.findAllElements('Relationship').forEach((node) {
      final id = node.getAttribute('Id');
      final target = node.getAttribute('Target');
      final type = node.getAttribute('Type');
      if (id == null || target == null || type == null) return;
      
      if (type.endsWith('/image')) {
        _imagePaths[id] = 'word/$target';
      } else if (type.endsWith('/hyperlink')) {
        _hyperlinkUrls[id] = target;
      }
    });
  }

  void _loadStyles() {
    final stylesFile = _archive.findFile('word/styles.xml');
    if (stylesFile == null) return;

    final stylesContent = utf8.decode(stylesFile.content as List<int>);
    final stylesDoc = XmlDocument.parse(stylesContent);
    stylesDoc.findAllElements('w:style').forEach((node) {
      final styleId = node.getAttribute('w:styleId');
      if (styleId != null) {
        _styles[styleId] = _parseStyleProperties(node);
      }
    });
  }
  
  // ---------------- WIDGET BUILDERS ----------------

  Widget? _buildParagraphWidget(XmlElement p) {
    final pStyle = _parseParagraphStyle(p);
    final inlineSpans = _processParagraphContent(p, pStyle);

    if (inlineSpans.isEmpty) return SizedBox(height: pStyle.fontSize ?? 16.0); // Render empty lines

    final numPr = p.findElements('w:pPr').firstOrNull?.findElements('w:numPr').firstOrNull;
    Widget child;

    if (numPr != null) {
      final level = numPr.findElements('w:ilvl').firstOrNull?.getAttribute('w:val') ?? '0';
      final numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val');
      
      if (numId != null) {
        final bulletText = _numbering.getBulletText(numId, level);
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 25.0 * (int.tryParse(level) ?? 0),
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  bulletText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: pStyle.fontSize, color: _parseColor(pStyle.color)),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: RichText(
                textAlign: pStyle.alignment ?? TextAlign.start,
                text: TextSpan(children: inlineSpans),
              ),
            ),
          ],
        );
      } else {
         child = RichText(
          textAlign: pStyle.alignment ?? TextAlign.start,
          text: TextSpan(children: inlineSpans),
        );
      }
    } else {
      child = RichText(
        textAlign: pStyle.alignment ?? TextAlign.start,
        text: TextSpan(children: inlineSpans),
      );
    }
    
    return Padding(
      padding: EdgeInsets.only(
        top: pStyle.spacingBefore ?? 0.0,
        bottom: pStyle.spacingAfter ?? 8.0,
        left: pStyle.indentLeft ?? 0.0,
      ),
      child: child,
    );
  }

  Widget? _buildTableWidget(XmlElement table) {
    final rows = table.findAllElements('w:tr');
    if (rows.isEmpty) return null;

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      children: rows.map((row) {
        return TableRow(
          children: row.findAllElements('w:tc').map((cell) {
            final cellStyle = _parseStyleProperties(cell.findElements('w:tcPr').firstOrNull);

            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Container(
                color: _parseColor(cellStyle.cellColor),
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cell.findAllElements('w:p')
                    .map((p) => _buildParagraphWidget(p))
                    .whereType<Widget>()
                    .toList(),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ---------------- CONTENT PROCESSORS ----------------

  List<InlineSpan> _processParagraphContent(XmlElement paragraph, DocxStyle baseStyle) {
    List<InlineSpan> spans = [];

    // Apply first-line indentation
    if ((baseStyle.indentFirstLine ?? 0) > 0) {
      spans.add(WidgetSpan(child: SizedBox(width: baseStyle.indentFirstLine)));
    }

    for (final node in paragraph.children.whereType<XmlElement>()) {
      if (node.name.local == 'r') {
        spans.add(_processTextRun(node, baseStyle));
      } else if (node.name.local == 'hyperlink') {
        spans.add(_processHyperlink(node, baseStyle));
      }
    }
    return spans;
  }

  InlineSpan _processHyperlink(XmlElement link, DocxStyle baseStyle) {
    final linkId = link.getAttribute('r:id');
    final url = (linkId != null) ? _hyperlinkUrls[linkId] : null;
    
    final textSpans = link.findAllElements('w:r')
      .map((run) => _processTextRun(run, baseStyle, isHyperlink: true))
      .toList();
      
    if (url != null) {
      return TextSpan(
        children: textSpans,
        style: const TextStyle(
          color: Colors.blue, 
          decoration: TextDecoration.underline
        ),
        recognizer: TapGestureRecognizer()..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
      );
    }
    // If no URL, render as plain text
    return TextSpan(children: textSpans);
  }

  InlineSpan _processTextRun(XmlElement run, DocxStyle baseStyle, {bool isHyperlink = false}) {
    final directStyle = _parseStyleProperties(run);
    final finalStyle = baseStyle.merge(directStyle);
    
    // Process children of the run
    List<InlineSpan> children = [];
    for (final child in run.children.whereType<XmlElement>()) {
      if (child.name.local == 't') {
        children.add(TextSpan(text: child.text));
      } else if (child.name.local == 'tab') {
        children.add(const TextSpan(text: '\t'));
      } else if (child.name.local == 'drawing' || child.name.local == 'pict') {
        final imageSpan = _processImage(child);
        if (imageSpan != null) children.add(imageSpan);
      }
    }
    
    // If it's just text, combine into a single TextSpan for simplicity
    if (children.every((s) => s is TextSpan)) {
      final text = children.map((s) => (s as TextSpan).text).join();
      return TextSpan(
        text: text,
        style: _getTextStyle(finalStyle, isHyperlink: isHyperlink),
      );
    }
    
    // If it contains widgets (like images), return a TextSpan with children
    return TextSpan(
      style: _getTextStyle(finalStyle, isHyperlink: isHyperlink),
      children: children,
    );
  }

  WidgetSpan? _processImage(XmlElement drawingElement) {
    final blipElement = drawingElement.findAllElements('a:blip').firstOrNull;
    final embedId = blipElement?.getAttribute('r:embed') ??
                    drawingElement.findAllElements('v:imagedata').firstOrNull?.getAttribute('r:id');

    if (embedId != null && _imagePaths.containsKey(embedId)) {
      final imagePath = _imagePaths[embedId]!;
      final imageFile = _archive.findFile(imagePath);
      if (imageFile != null) {
        final bytes = Uint8List.fromList(imageFile.content as List<int>);
        return WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.memory(bytes),
          ),
        );
      }
    }
    return null;
  }
  
  // ---------------- STYLE PARSERS ----------------

  DocxStyle _parseParagraphStyle(XmlElement p) {
    final pPr = p.findElements('w:pPr').firstOrNull;
    if (pPr == null) return DocxStyle();

    final styleId = pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
    DocxStyle style = _styles[styleId] ?? DocxStyle();

    final directStyle = _parseStyleProperties(pPr);
    return style.merge(directStyle);
  }

  DocxStyle _parseStyleProperties(XmlElement? element) {
    if (element == null) return DocxStyle();

    // Find the relevant properties element (rPr for runs, pPr for paragraphs)
    final rPr = element.findElements('w:rPr').firstOrNull ?? (element.name.local == 'rPr' ? element : null);
    final pPr = element.name.local == 'pPr' ? element : null;

    // Text formatting
    final isBold = rPr?.findElements('w:b').isNotEmpty ?? false;
    final isItalic = rPr?.findElements('w:i').isNotEmpty ?? false;
    final underlineNode = rPr?.findElements('w:u').firstOrNull;
    final isUnderline = underlineNode != null && underlineNode.getAttribute('w:val') != 'none';
    final color = rPr?.findElements('w:color').firstOrNull?.getAttribute('w:val');
    final sz = rPr?.findElements('w:sz').firstOrNull?.getAttribute('w:val');
    final fontSize = (sz != null) ? double.tryParse(sz) : null;

    // Paragraph alignment
    final alignmentVal = pPr?.findElements('w:jc').firstOrNull?.getAttribute('w:val');
    TextAlign? alignment;
    if (alignmentVal == 'center') alignment = TextAlign.center;
    if (alignmentVal == 'right') alignment = TextAlign.right;
    if (alignmentVal == 'both') alignment = TextAlign.justify;

    // Paragraph spacing
    final spacing = pPr?.findElements('w:spacing').firstOrNull;
    final before = spacing?.getAttribute('w:before');
    final after = spacing?.getAttribute('w:after');
    
    // Paragraph indentation
    final ind = pPr?.findElements('w:ind').firstOrNull;
    final left = ind?.getAttribute('w:left') ?? ind?.getAttribute('w:start');
    final firstLine = ind?.getAttribute('w:firstLine');

    // Table cell shading
    final cellColor = element.findElements('w:shd').firstOrNull?.getAttribute('w:fill');

    return DocxStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      color: color,
      cellColor: cellColor,
      fontSize: fontSize != null ? fontSize / 2 : null, // Font size is in half-points
      alignment: alignment,
      spacingBefore: _twipsToPoints(before),
      spacingAfter: _twipsToPoints(after),
      indentLeft: _twipsToPoints(left),
      indentFirstLine: _twipsToPoints(firstLine),
    );
  }
  
  // ---------------- UTILITY HELPERS ----------------

  TextStyle _getTextStyle(DocxStyle style, {bool isHyperlink = false}) {
    return TextStyle(
      fontWeight: style.isBold == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: style.isItalic == true ? FontStyle.italic : FontStyle.normal,
      decoration: style.isUnderline == true ? TextDecoration.underline : TextDecoration.none,
      color: isHyperlink ? Colors.blue : _parseColor(style.color),
      fontSize: style.fontSize,
      height: 1.5,
    );
  }

  Color _parseColor(String? colorValue) {
    if (colorValue == null || colorValue == 'auto') return Colors.black;
    try {
      return Color(int.parse('FF$colorValue', radix: 16));
    } catch (e) {
      return Colors.black;
    }
  }

  double? _twipsToPoints(String? twips) {
    if (twips == null) return null;
    final value = double.tryParse(twips);
    return (value != null) ? value / 20.0 : null;
  }
}

// ----------------------------------------------------
// ----------------- FLUTTER UI -----------------------
// ----------------------------------------------------

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
  List<Widget> _documentContent = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAndParseDocument();
  }

  Future<void> _loadAndParseDocument() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) throw Exception("File does not exist.");

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final parser = DocxParser(archive);
      final widgets = await parser.parseDocument();

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
          errorMessage = "Failed to open file. This viewer supports modern .docx files, but not the older .doc binary format.";
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        elevation: 1,
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