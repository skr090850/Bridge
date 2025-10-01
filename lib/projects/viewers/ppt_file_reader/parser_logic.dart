import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

import 'data_model.dart';
import '../doc_file_reader/theme_manager.dart';

// Helper to safely get the first element
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

const double _emuPerPixel = 9525;

class PptxParser {
  final Archive _archive;
  final Map<String, String> _presentationRels = {};
  final Map<String, Map<String, String>> _slideRels = {};
  final Map<String, Map<String, String>> _slideMasterRels = {};

  final Map<String, SlideMaster> _slideMasters = {};
  
  late final ThemeManager _themeManager;
  late final Size _slideSize;

  PptxParser(this._archive);

  /// --- START: RELIABLE PATH RESOLVER ---
  /// Yeh function ab Dart ke standard Uri class ka istemal karta hai.
  /// Yeh relative paths (jaise '../') ko hamesha sahi tareeke se handle karega.
  String _resolvePath(String fromPath, String relativePath) {
    // We use a dummy base URI because we are only interested in path resolution.
    final fromUri = Uri.parse('file:/$fromPath'); 
    final resolvedUri = fromUri.resolve(relativePath);
    // Remove the leading '/' to match the archive's path format.
    final finalPath = resolvedUri.path.substring(1);
    // debugPrint('[PptxParser] >>     [Path Resolver] from: "$fromPath", rel: "$relativePath" -> resolved: "$finalPath"');
    return finalPath;
  }
  /// --- END: RELIABLE PATH RESOLVER ---

  ArchiveFile? _findFileByPath(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
     for (final file in _archive.files) {
      if (file.name.replaceAll('\\', '/') == normalizedPath) {
        return file;
      }
    }
    debugPrint('[PptxParser] >> ⚠️ Path se File NAHI Mili: $path');
    return null;
  }
  
  ArchiveFile? _findFileByName(String fileName) {
    final lowerCaseFileName = fileName.toLowerCase();
    for (final file in _archive.files) {
      if (p.basename(file.name).toLowerCase() == lowerCaseFileName) {
        debugPrint('[PptxParser] >> ✅ Naam se File Mili: ${file.name}');
        return file;
      }
    }
    debugPrint('[PptxParser] >> ⚠️ Naam se File NAHI Mili: $fileName');
    return null;
  }

  Future<PptxPresentation> parseDocument() async {
    debugPrint('[PptxParser] >> Document parsing shuru ho raha hai...');
    
    final presentationFile = _findFileByName('presentation.xml');
    if (presentationFile == null) {
      debugPrint('[PptxParser] >> ❌ ERROR: presentation.xml nahi mili. Parsing ruk gayi.');
      throw Exception('presentation.xml not found');
    }
    final presentationPath = presentationFile.name;
    _loadRelsForPart(presentationPath); 

    final themeFile = _archive.files.firstWhere(
      (file) => p.basename(file.name).startsWith('theme') && file.name.endsWith('.xml'),
      orElse: () {
        debugPrint('[PptxParser] >> Koi theme file nahi mili.');
        return ArchiveFile('', 0, []); 
      },
    );

    _themeManager = ThemeManager(_archive, themePath: themeFile.name);
    debugPrint('[PptxParser] >> ThemeManager is path se initialize hua: "${themeFile.name}"');
    
    final presentationXml = _getXmlDocument(presentationPath);
    if (presentationXml == null) {
      throw Exception('presentation.xml could not be parsed.');
    }

    final sldSz = presentationXml.findAllElements('p:sldSz').firstOrNull;
    final cx = double.tryParse(sldSz?.getAttribute('cx') ?? '0') ?? 0;
    final cy = double.tryParse(sldSz?.getAttribute('cy') ?? '0') ?? 0;
    _slideSize = Size(cx, cy);
    debugPrint('[PptxParser] >> Slide ka size: $_slideSize');

    await _parseSlideMasters(presentationXml, presentationPath);
    
    final sldIdLst = presentationXml.findAllElements('p:sldIdLst').firstOrNull;
    if (sldIdLst == null) {
      debugPrint('[PptxParser] >> ⚠️ Is presentation mein koi slide list nahi hai.');
      return PptxPresentation(slides: [], slideSize: _slideSize);
    }
    
    List<PptxSlide> slides = [];
    for (final sldId in sldIdLst.findAllElements('p:sldId')) {
      final relId = sldId.getAttribute('r:id');
      if (relId == null) continue;

      final slidePath = _presentationRels[relId];
      if (slidePath != null) {
        final fullSlidePath = _resolvePath(presentationPath, slidePath);
        _loadRelsForPart(fullSlidePath);
        final slide = await _parseSlide(fullSlidePath);
        slides.add(slide);
      }
    }

    debugPrint('[PptxParser] >> Parsing poori hui. Kul ${slides.length} slides mili.');
    return PptxPresentation(slides: slides, slideSize: _slideSize);
  }
  
  void _loadRelsForPart(String partPath) {
      final relsPath = p.join(p.dirname(partPath), '_rels', '${p.basename(partPath)}.rels');
      final relsFile = _findFileByPath(relsPath);
      if (relsFile == null) return;
      
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

      if (partPath.endsWith('presentation.xml')) {
         _presentationRels.addAll(relationships);
      } else if (partPath.contains('slideMasters')) {
         _slideMasterRels[partPath] = relationships;
      } else {
         _slideRels[partPath] = relationships;
      }
  }

  Future<void> _parseSlideMasters(XmlDocument presentationXml, String presentationPath) async {
    final sldMasterIdLst = presentationXml.findAllElements('p:sldMasterIdLst').firstOrNull;
    if (sldMasterIdLst == null) return;

    for (final sldMasterId in sldMasterIdLst.findAllElements('p:sldMasterId')) {
      final relId = sldMasterId.getAttribute('r:id');
      if (relId == null) continue;

      final masterPath = _presentationRels[relId];
      if (masterPath != null) {
        final fullMasterPath = _resolvePath(presentationPath, masterPath);
        _loadRelsForPart(fullMasterPath);
        
        final masterXml = _getXmlDocument(fullMasterPath);
        if (masterXml == null) continue;

        final background = _parseBackground(masterXml.rootElement);
        final layouts = await _parseSlideLayouts(fullMasterPath);

        _slideMasters[fullMasterPath] = SlideMaster(layouts: layouts, background: background);
      }
    }
  }

  Future<Map<String, SlideLayout>> _parseSlideLayouts(String masterPath) async {
    final masterRels = _slideMasterRels[masterPath] ?? {};
    Map<String, SlideLayout> layouts = {};

    for(final relId in masterRels.keys) {
      final targetPath = masterRels[relId]!;
      if (targetPath.contains('slideLayouts/')) {
        final fullLayoutPath = _resolvePath(masterPath, targetPath);
        final layoutXml = _getXmlDocument(fullLayoutPath);
        if (layoutXml == null) continue;

        final spTree = layoutXml.findAllElements('p:spTree').firstOrNull;
        if (spTree == null) continue;

        final background = _parseBackground(layoutXml.rootElement);
        final children = _parseShapeTree(spTree, fullLayoutPath);
        
        layouts[fullLayoutPath] = SlideLayout(children: children, background: background);
      }
    }
    return layouts;
  }


  Future<PptxSlide> _parseSlide(String slidePath) async {
    debugPrint('[PptxParser] >> --- Slide Parse Ho Rahi Hai: $slidePath ---');
    final slideXml = _getXmlDocument(slidePath);
    if (slideXml == null) {
        debugPrint('[PptxParser] >>   ❌ ERROR: Is slide ke liye XML nahi mili!');
        return PptxSlide(children: []);
    }

    final layoutRelId = slideXml.rootElement.findAllElements('p:sldLayoutId').firstOrNull?.getAttribute('r:id');
    final slideRels = _slideRels[slidePath] ?? {};
    final relativeLayoutPath = layoutRelId != null ? slideRels[layoutRelId] : null;
    
    SlideLayout? layout;

    if (relativeLayoutPath != null) {
      final fullLayoutPath = _resolvePath(slidePath, relativeLayoutPath);
      
      for (final master in _slideMasters.values) {
        if (master.layouts.containsKey(fullLayoutPath)) {
          layout = master.layouts[fullLayoutPath];
          break;
        }
      }
    }

    if (layout != null) {
        debugPrint('[PptxParser] >>   ✅ Layout Mila!');
    } else {
        debugPrint('[PptxParser] >>   ⚠️ Is slide ke liye koi layout nahi mila.');
    }
    
    List<Widget> slideChildren = [];
    if (layout != null) {
      slideChildren.addAll(layout.children);
    }
    
    final spTree = slideXml.findAllElements('p:spTree').firstOrNull;
    if (spTree != null) {
      slideChildren.addAll(_parseShapeTree(spTree, slidePath));
    }

    debugPrint('[PptxParser] >>   Slide ke liye ${slideChildren.length} child widgets banaye gaye.');
    final background = _parseBackground(slideXml.rootElement) ?? layout?.background;
    
    final notesRelEntry = slideRels.entries.firstWhere(
            (entry) => entry.value.contains('../notesSlides/'),
            orElse: () => const MapEntry('', '')
    );
    List<Widget> notesWidgets = [];
    if (notesRelEntry.key.isNotEmpty) {
        final notesPath = notesRelEntry.value;
        final fullNotesPath = _resolvePath(slidePath, notesPath);
        notesWidgets = _parseNotesSlide(fullNotesPath);
    }

    return PptxSlide(children: slideChildren, background: background, notes: notesWidgets);
  }

  List<Widget> _parseShapeTree(XmlElement spTree, String partPath) {
    List<Widget> children = [];
    final elements = spTree.children.whereType<XmlElement>().where(
      (e) => e.name.local == 'sp' || e.name.local == 'pic' || e.name.local == 'cxnSp'
    );

    for (final element in elements) {
      final xfrm = element.findAllElements('p:xfrm').firstOrNull;
      if (xfrm == null) continue;

      final off = xfrm.findAllElements('a:off').firstOrNull;
      final ext = xfrm.findAllElements('a:ext').firstOrNull;
      
      final x = double.tryParse(off?.getAttribute('x') ?? '0') ?? 0;
      final y = double.tryParse(off?.getAttribute('y') ?? '0') ?? 0;
      final cx = double.tryParse(ext?.getAttribute('cx') ?? '0') ?? 0;
      final cy = double.tryParse(ext?.getAttribute('cy') ?? '0') ?? 0;
      final rot = double.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;
      
      Widget? child;
      if (element.name.local == 'sp') {
         child = _buildTextBox(element);
      } else if (element.name.local == 'pic') {
         child = _buildPicture(element, partPath);
      } else if (element.name.local == 'cxnSp') {
         child = _buildConnectorShape(element);
      }

      if(child != null) {
        final angle = (rot / 60000) * (pi / 180);
        children.add(
          _PositionedEmu(x: x, y: y, cx: cx, cy: cy, child: Transform.rotate(
            angle: angle,
            child: child,
          ))
        );
      }
    }
    return children;
  }

  Widget? _buildTextBox(XmlElement sp) {
    final txBody = sp.findAllElements('p:txBody').firstOrNull;
    if(txBody == null) return Container();

    final textSpans = txBody.findAllElements('a:p').map((p) {
      final pPr = p.findAllElements('a:pPr').firstOrNull;
      TextAlign textAlign = TextAlign.start;
      final algn = pPr?.getAttribute('algn');
      if (algn == 'ctr') textAlign = TextAlign.center;
      if (algn == 'r') textAlign = TextAlign.end;
      if (algn == 'just') textAlign = TextAlign.justify;
      
      List<InlineSpan> spans = p.findAllElements('a:r').map<InlineSpan>((r) {
        final text = r.findAllElements('a:t').firstOrNull?.text ?? '';
        final rPr = r.findAllElements('a:rPr').firstOrNull;
        return _createTextSpan(text, rPr);
      }).toList();

      if (spans.isEmpty) {
        return null; 
      }

      return RichText(
        textAlign: textAlign,
        text: TextSpan(children: spans),
      );
    }).whereType<RichText>().toList();


    if (textSpans.isEmpty) return Container();

    final bodyPr = txBody.findAllElements('a:bodyPr').firstOrNull;
    final anchor = bodyPr?.getAttribute('anchor');
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start;
    if(anchor == 'ctr') mainAxisAlignment = MainAxisAlignment.center;
    if(anchor == 'b') mainAxisAlignment = MainAxisAlignment.end;

    final lIns = double.tryParse(bodyPr?.getAttribute('lIns') ?? '0') ?? 0;
    final tIns = double.tryParse(bodyPr?.getAttribute('tIns') ?? '0') ?? 0;
    final rIns = double.tryParse(bodyPr?.getAttribute('rIns') ?? '0') ?? 0;
    final bIns = double.tryParse(bodyPr?.getAttribute('bIns') ?? '0') ?? 0;

    final spPr = sp.findAllElements('p:spPr').firstOrNull;
    Color? fillColor;
    BoxBorder? border;

    if (spPr != null) {
       fillColor = _getColorFromFill(spPr.findAllElements('a:solidFill').firstOrNull);
       final ln = spPr.findAllElements('a:ln').firstOrNull;
       if (ln != null) {
          final borderColor = _getColorFromFill(ln.findAllElements('a:solidFill').firstOrNull);
          final width = double.tryParse(ln.getAttribute('w') ?? '9525') ?? 9525;
          border = Border.all(color: borderColor ?? Colors.transparent, width: width / _emuPerPixel);
       }
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.fromLTRB(lIns/_emuPerPixel, tIns/_emuPerPixel, rIns/_emuPerPixel, bIns/_emuPerPixel),
      decoration: BoxDecoration(
        color: fillColor,
        border: border,
      ),
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: textSpans,
      ),
    );
  }
  
  Widget _buildConnectorShape(XmlElement cxnSp) {
    final spPr = cxnSp.findAllElements('p:spPr').firstOrNull;
    Color? lineColor;
    double lineWidth = 1.0;

    if (spPr != null) {
      final ln = spPr.findAllElements('a:ln').firstOrNull;
       if (ln != null) {
          lineColor = _getColorFromFill(ln.findAllElements('a:solidFill').firstOrNull);
          lineWidth = (double.tryParse(ln.getAttribute('w') ?? '9525') ?? 9525) / _emuPerPixel;
       }
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: lineColor ?? Colors.transparent,
            width: lineWidth,
          ),
        ),
      ),
    );
  }

  Widget? _buildPicture(XmlElement pic, String partPath) {
    final blip = pic.findAllElements('a:blip').firstOrNull;
    final relId = blip?.getAttribute('r:embed');
    if (relId == null) return null;

    final imageTarget = (_slideRels[partPath] ?? _slideMasterRels[partPath])?[relId];
    if (imageTarget == null) return null;

    final fullImagePath = _resolvePath(partPath, imageTarget);
    final imageFile = _findFileByPath(fullImagePath);
    
    if (imageFile != null) {
      final bytes = Uint8List.fromList(imageFile.content as List<int>);
      return Image.memory(bytes, fit: BoxFit.fill);
    }
    return null;
  }

  String? _parseBackground(XmlElement element) {
    final bg = element.findAllElements('p:bg').firstOrNull;
    final bgPr = bg?.findAllElements('p:bgPr').firstOrNull;
    final solidFill = bgPr?.findAllElements('a:solidFill').firstOrNull;
    if(solidFill != null) {
       return _getColorFromFill(solidFill)?.value.toRadixString(16).substring(2);
    }
    return null;
  }
  
  List<Widget> _parseNotesSlide(String notesPath) {
      final notesXml = _getXmlDocument(notesPath);
      if (notesXml == null) return [];

      List<Widget> notesContent = [];
      final textBodies = notesXml.findAllElements('p:txBody');

      for (final txBody in textBodies) {
          List<InlineSpan> spans = [];
          for (final p in txBody.findAllElements('a:p')) {
              for (final r in p.findAllElements('a:r')) {
                  final text = r.findAllElements('a:t').firstOrNull?.text ?? '';
                  final rPr = r.findAllElements('a:rPr').firstOrNull;
                  spans.add(_createTextSpan(text, rPr));
              }
              spans.add(const TextSpan(text: '\n'));
          }
            if (spans.isNotEmpty) {
              spans.removeLast();
            }
            if (spans.any((s) => s is TextSpan && (s.text?.trim().isNotEmpty ?? false))) {
              notesContent.add(RichText(text: TextSpan(children: spans, style: const TextStyle(color: Colors.black, fontSize: 14))));
            }
      }
      return notesContent;
  }

  Color? _getColorFromFill(XmlElement? fillElement) {
      if (fillElement == null) return null;
      final srgbClr = fillElement.findAllElements('a:srgbClr').firstOrNull;
      final schemeClr = fillElement.findAllElements('a:schemeClr').firstOrNull;

      if(srgbClr != null) {
         final colorVal = srgbClr.getAttribute('val');
         if(colorVal != null) return _parseColor(colorVal);
      } else if (schemeClr != null) {
        final colorName = schemeClr.getAttribute('val');
        if(colorName != null) {
           final themeColor = _themeManager.getColor(colorName);
           if(themeColor != null) return _parseColor(themeColor);
        }
      }
      return null;
  }

  TextSpan _createTextSpan(String text, XmlElement? rPr) {
    Color color = Colors.black;
    double fontSize = 18.0;
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    bool isStrikethrough = false;
    
    if (rPr != null) {
      isBold = rPr.getAttribute('b') == '1';
      isItalic = rPr.getAttribute('i') == '1';
      isUnderline = rPr.getAttribute('u') == 'sng';
      isStrikethrough = rPr.getAttribute('strike') == 'sngStrike';
      
      final sz = rPr.getAttribute('sz');
      if (sz != null) {
        fontSize = (double.tryParse(sz) ?? 1800) / 100.0;
      }
      
      final solidFill = rPr.findAllElements('a:solidFill').firstOrNull;
      if (solidFill != null) {
         color = _getColorFromFill(solidFill) ?? color;
      }
    }

    final List<TextDecoration> decorations = [];
    if(isUnderline) decorations.add(TextDecoration.underline);
    if(isStrikethrough) decorations.add(TextDecoration.lineThrough);

    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: TextDecoration.combine(decorations),
      ),
    );
  }

  XmlDocument? _getXmlDocument(String path) {
    final file = _findFileByPath(path);
    if (file == null) return null;
    final content = utf8.decode(file.content as List<int>, allowMalformed: true);
    return XmlDocument.parse(content);
  }

  Color? _parseColor(String? colorValue) {
    if (colorValue == null) return null;
    try {
      final hex = colorValue.padLeft(6, '0');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return null;
    }
  }
}

/// A helper widget to position children using EMU units.
class _PositionedEmu extends StatelessWidget {
  final double x, y, cx, cy;
  final Widget child;

  const _PositionedEmu({
    required this.x,
    required this.y,
    required this.cx,
    required this.cy,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double left = x / _emuPerPixel;
    final double top = y / _emuPerPixel;
    final double width = cx / _emuPerPixel;
    final double height = cy / _emuPerPixel;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
  }
}

