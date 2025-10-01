import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import 'document_model.dart';
import 'doc_style_model.dart';
import 'numbering_manager.dart';
import 'theme_manager.dart';

// Extension to safely get the first element of an iterable or return null.
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DocxParser {
  final Archive _archive;
  final Map<String, DocxStyle> _styles = {};
  // Main document relationships
  final Map<String, String> _documentRels = {};
  // Relationships for other parts (headers, footers, etc.), keyed by part path
  final Map<String, Map<String, String>> _partRels = {};

  late final ThemeManager _themeManager;
  late final NumberingManager _numbering;

  DocxParser(this._archive) {
    _numbering = NumberingManager(_archive);
    _themeManager = ThemeManager(_archive);
    _loadAllRelationships();
    _loadStyles();
  }

  Future<DocxDocument> parseDocument() async {
    const mainDocPath = 'word/document.xml';
    final bodyWidgets = await _parseXmlContent(mainDocPath);

    final docFile = _archive.findFile(mainDocPath);
    if (docFile == null) {
      return DocxDocument(headers: [], body: bodyWidgets, footers: []);
    }
    final docContent =
        utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final docXml = XmlDocument.parse(docContent);
    final sectPr = docXml.findAllElements('w:sectPr').firstOrNull;

    List<Widget> headerWidgets = [];
    List<Widget> footerWidgets = [];

    if (sectPr != null) {
      for (final headerRef in sectPr.findAllElements('w:headerReference')) {
        final relId = headerRef.getAttribute('r:id');
        final headerPath = _documentRels[relId];
        if (headerPath != null) {
          headerWidgets
              .addAll(await _parseXmlContent(p.join('word', headerPath)));
        }
      }

      for (final footerRef in sectPr.findAllElements('w:footerReference')) {
        final relId = footerRef.getAttribute('r:id');
        final footerPath = _documentRels[relId];
        if (footerPath != null) {
          footerWidgets
              .addAll(await _parseXmlContent(p.join('word', footerPath)));
        }
      }
    }

    return DocxDocument(
      headers: headerWidgets,
      body: bodyWidgets,
      footers: footerWidgets,
    );
  }

  Future<List<Widget>> _parseXmlContent(String xmlPath) async {
    final docxFile = _archive.findFile(xmlPath);
    if (docxFile == null) return [];

    final docxContent =
        utf8.decode(docxFile.content as List<int>, allowMalformed: true);
    final documentXml = XmlDocument.parse(docxContent);
    final body =
        documentXml.rootElement.children.whereType<XmlElement>().firstOrNull;

    if (body == null) return [];

    List<Widget> widgets = [];
    for (final element in body.children.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 'p':
          final pWidget = _buildParagraphWidget(element, partPath: xmlPath);
          if (pWidget != null) widgets.add(pWidget);
          break;
        case 'tbl':
          final tWidget = _buildTableWidget(element, partPath: xmlPath);
          if (tWidget != null) widgets.add(tWidget);
          break;
      }
    }
    return widgets;
  }

  void _loadAllRelationships() {
    for (final file in _archive.files) {
      if (file.name.endsWith('.xml.rels')) {
        _loadRelationships(file);
      }
    }
  }

  void _loadRelationships(ArchiveFile relsFile) {
    final relsContent = utf8.decode(relsFile.content as List<int>);
    final relsDoc = XmlDocument.parse(relsContent);
    final relationships = <String, String>{};

    relsDoc.findAllElements('Relationship').forEach((node) {
      final id = node.getAttribute('Id');
      final target = node.getAttribute('Target');
      if (id != null && target != null) {
        relationships[id] = target;
      }
    });

    final partName = p.normalize(relsFile.name.replaceAll('_rels/', '').replaceAll('.rels', ''));
    
    if (partName == 'word/document.xml') {
      _documentRels.addAll(relationships);
    } else {
      _partRels[partName] = relationships;
    }
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

  Widget? _buildParagraphWidget(XmlElement p, {DocxStyle? baseStyle, required String partPath}) {
    final pStyle = _parseParagraphStyle(p, baseStyle: baseStyle);
    
    // FIX: Numbering info ko pehle check karein
    final numPr = p.findElements('w:pPr').firstOrNull?.findElements('w:numPr').firstOrNull;
    final numId = numPr?.findElements('w:numId').firstOrNull?.getAttribute('w:val');
    final bool isNumbered = numId != null;

    // FIX: Flag pass karein taaki first-line indent na lage
    final inlineSpans = _processParagraphContent(p, pStyle, partPath, isNumbered: isNumbered);

    if (inlineSpans.isEmpty && p.children.whereType<XmlElement>().isEmpty) {
       final height = pStyle.spacingAfter ?? pStyle.fontSize ?? 16.0;
      return SizedBox(height: height > 0 ? height : 16.0);
    }

    Widget child;

    // SUDHAR: Numbering logic ko wapas theek kiya gaya
    if (isNumbered) {
      final level = numPr!.findElements('w:ilvl').firstOrNull?.getAttribute('w:val') ?? '0';
      final bulletText = _numbering.getBulletText(numId, level);
      final defaultIndent = 36.0 * (double.tryParse(level) ?? 0);
      final bulletWidth = max(0.0, (pStyle.indentLeft ?? defaultIndent) - 6);

      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: bulletWidth,
            child: Text(
              bulletText,
              textAlign: TextAlign.right,
              softWrap: false, // Ensure numbers like "12" don't wrap
              style: _getTextStyle(pStyle),
            ),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: RichText(
              textAlign: pStyle.alignment ?? TextAlign.justify,
              text: TextSpan(children: inlineSpans, style: _getTextStyle(pStyle)),
            ),
          ),
        ],
      );
    } else {
      child = RichText(
        textAlign: pStyle.alignment ?? TextAlign.justify,
        text: TextSpan(children: inlineSpans, style: _getTextStyle(pStyle)),
      );
    }
    
    // Hanging indentation ko support kiya gaya
    double leftPadding = pStyle.indentLeft ?? 0;
    double firstLineIndent = pStyle.indentFirstLine ?? 0;
    if (pStyle.indentHanging != null) {
      leftPadding += pStyle.indentHanging!;
      firstLineIndent -= pStyle.indentHanging!;
    }
    
    if (isNumbered) {
      leftPadding = 0; // Numbering ke liye padding Row se handle hoti hai
    }

    return Padding(
      padding: EdgeInsets.only(
        top: pStyle.spacingBefore ?? 0.0,
        bottom: pStyle.spacingAfter ?? 8.0,
        left: leftPadding,
        right: pStyle.indentRight ?? 0.0,
      ),
      child: child,
    );
  }

  Widget? _buildTableWidget(XmlElement table, {required String partPath}) {
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
                  children: cell
                      .findAllElements('w:p')
                      .map((p) => _buildParagraphWidget(p,
                          baseStyle: cellStyle, partPath: partPath))
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

  // FIX: isNumbered parameter add kiya gaya
  List<InlineSpan> _processParagraphContent(XmlElement paragraph, DocxStyle baseStyle, String partPath, {bool isNumbered = false}) {
    List<InlineSpan> spans = [];

    // FIX: Hanging indentation ke liye first line indent ko handle karein
    // Lekin agar numbered list hai to isko skip karein
    if (!isNumbered) {
      double firstLineIndent = baseStyle.indentFirstLine ?? 0;
      if (baseStyle.indentHanging != null) {
        firstLineIndent -= baseStyle.indentHanging!;
      }
      if (firstLineIndent > 0) {
        spans.add(WidgetSpan(child: SizedBox(width: firstLineIndent)));
      }
    }

    for (final node in paragraph.children.whereType<XmlElement>()) {
      if (node.name.local == 'r') {
        spans.add(_processTextRun(node, baseStyle, partPath));
      } else if (node.name.local == 'hyperlink') {
        spans.add(_processHyperlink(node, baseStyle, partPath));
      }
    }
    return spans;
  }

  InlineSpan _processHyperlink(XmlElement link, DocxStyle baseStyle, String partPath) {
    final relId = link.getAttribute('r:id');
    final rels = _partRels[p.normalize(partPath)] ?? _documentRels;
    final url = (relId != null) ? rels[relId] : null;

    final textSpans = link
        .findAllElements('w:r')
        .map((run) =>
            _processTextRun(run, baseStyle, partPath, isHyperlink: true))
        .toList();
    
    if (url == null || !url.startsWith('http')) {
      return TextSpan(children: textSpans);
    }

    return TextSpan(
      children: textSpans,
      style: const TextStyle(
          color: Colors.blue, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
    );
  }

  InlineSpan _processTextRun(XmlElement run, DocxStyle baseStyle, String partPath, {bool isHyperlink = false}) {
    final directStyle = _parseStyleProperties(run);
    final finalStyle = baseStyle.merge(directStyle);
    List<InlineSpan> children = [];

    for (final child in run.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 't':
          // FIX: Shabdon ko tootne se rokne ke liye plain text ka istemal
          children.add(TextSpan(text: child.text));
          break;
        case 'tab':
          children.add(const TextSpan(text: '\t'));
          break;
        case 'br':
          children.add(const TextSpan(text: '\n'));
          break;
        case 'drawing':
        case 'pict':
          final imageSpan = _processImage(child, partPath);
          if (imageSpan != null) children.add(imageSpan);
          break;
      }
    }

    // TextSpan ko parent style de taaki sabhi children par apply ho
    return TextSpan(
      style: _getTextStyle(finalStyle, isHyperlink: isHyperlink),
      children: children,
    );
  }

  WidgetSpan? _processImage(XmlElement drawingElement, String partPath) {
    final blipElement = drawingElement.findAllElements('a:blip').firstOrNull;
    final embedId = blipElement?.getAttribute('r:embed') ??
        drawingElement
            .findAllElements('v:imagedata')
            .firstOrNull
            ?.getAttribute('r:id');

    if (embedId == null) return null;
    
    final normalizedPartPath = p.normalize(partPath);
    final rels = _partRels[normalizedPartPath] ?? _documentRels;
    final imageTarget = rels[embedId];

    if (imageTarget != null) {
      final partDir = p.dirname(normalizedPartPath);
      final imagePath = p.normalize(p.join(partDir, imageTarget));
      
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

  DocxStyle _parseParagraphStyle(XmlElement p, {DocxStyle? baseStyle}) {
    final pPr = p.findElements('w:pPr').firstOrNull;
    DocxStyle style = baseStyle ?? DocxStyle();

    if (pPr == null) return style;

    final styleId =
        pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
    style = style.merge(_styles[styleId]);

    final directStyle = _parseStyleProperties(pPr);
    return style.merge(directStyle);
  }

  DocxStyle _parseStyleProperties(XmlElement? element) {
    if (element == null) return DocxStyle();

    final rPr = element.findElements('w:rPr').firstOrNull ??
        (element.name.local == 'rPr' ? element : null);
    final pPr = element.name.local == 'pPr' ? element : null;

    final rFonts = rPr?.findElements('w:rFonts').firstOrNull;
    String? fontFamily;
    if (rFonts != null) {
      final themeFont = rFonts.getAttribute('w:asciiTheme');
      if (themeFont != null) {
        if (themeFont.startsWith('major')) {
          fontFamily = _themeManager.getFont('majorFont');
        } else if (themeFont.startsWith('minor')) {
          fontFamily = _themeManager.getFont('minorFont');
        }
      }
      fontFamily ??= rFonts.getAttribute('w:ascii');
    }

    final colorNode = rPr?.findElements('w:color').firstOrNull;
    String? color;
    if (colorNode != null) {
      final themeColorName = colorNode.getAttribute('w:themeColor');
      if (themeColorName != null) {
        final tint = colorNode.getAttribute('w:themeTint');
        final shade = colorNode.getAttribute('w:themeShade');
        color = _themeManager.getColor(themeColorName, tint: tint, shade: shade);
      }
      color ??= colorNode.getAttribute('w:val');
    }

    final isBold = rPr?.findElements('w:b').isNotEmpty ?? false;
    final isItalic = rPr?.findElements('w:i').isNotEmpty ?? false;
    final underlineNode = rPr?.findElements('w:u').firstOrNull;
    final isUnderline =
        underlineNode != null && underlineNode.getAttribute('w:val') != 'none';
    final sz = rPr?.findElements('w:sz').firstOrNull?.getAttribute('w:val');
    final fontSize = (sz != null) ? double.tryParse(sz) : null;

    final alignmentVal =
        pPr?.findElements('w:jc').firstOrNull?.getAttribute('w:val');
    TextAlign? alignment;
    if (alignmentVal == 'center') alignment = TextAlign.center;
    if (alignmentVal == 'right') alignment = TextAlign.right;
    if (alignmentVal == 'both') alignment = TextAlign.justify;

    final spacing = pPr?.findElements('w:spacing').firstOrNull;
    final before = spacing?.getAttribute('w:before');
    final after = spacing?.getAttribute('w:after');

    final ind = pPr?.findElements('w:ind').firstOrNull;
    final left = ind?.getAttribute('w:left') ?? ind?.getAttribute('w:start');
    final right = ind?.getAttribute('w:right') ?? ind?.getAttribute('w:end');
    final firstLine = ind?.getAttribute('w:firstLine');
    final hanging = ind?.getAttribute('w:hanging');
    
    final cellColorNode = element.findElements('w:shd').firstOrNull;
    String? cellColor;
     if (cellColorNode != null) {
      final themeColorName = cellColorNode.getAttribute('w:themeFill');
      if (themeColorName != null) {
        final tint = cellColorNode.getAttribute('w:themeFillTint');
        final shade = cellColorNode.getAttribute('w:themeFillShade');
        cellColor = _themeManager.getColor(themeColorName, tint: tint, shade: shade);
      }
      cellColor ??= cellColorNode.getAttribute('w:fill');
    }


    return DocxStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      color: color,
      cellColor: cellColor,
      fontSize: fontSize != null ? fontSize / 2 : null,
      alignment: alignment,
      spacingBefore: _twipsToPoints(before),
      spacingAfter: _twipsToPoints(after),
      indentLeft: _twipsToPoints(left),
      indentRight: _twipsToPoints(right),
      indentFirstLine: _twipsToPoints(firstLine),
      indentHanging: _twipsToPoints(hanging),
      fontFamily: fontFamily,
    );
  }

  TextStyle _getTextStyle(DocxStyle style, {bool isHyperlink = false}) {
    return TextStyle(
      fontWeight: style.isBold == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: style.isItalic == true ? FontStyle.italic : FontStyle.normal,
      decoration: style.isUnderline == true
          ? TextDecoration.underline
          : TextDecoration.none,
      color:
          isHyperlink ? Colors.blue : (_parseColor(style.color) ?? Colors.black),
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
      height: 1.5,
    );
  }

  Color? _parseColor(String? colorValue) {
    if (colorValue == null || colorValue == 'auto') return null;
    try {
      final hex = colorValue.padLeft(6, '0');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return null;
    }
  }

  double? _twipsToPoints(String? twips) {
    if (twips == null) return null;
    final value = double.tryParse(twips);
    return (value != null) ? value / 20.0 : null;
  }
}
