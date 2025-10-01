import 'dart:convert';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

// Extension to safely get the first element of an iterable or return null.
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Theme-specific information ko parse aur provide karta hai,
/// mukhya roop se `word/theme/theme1.xml` se.
class ThemeManager {
  final Map<String, String> _colorScheme = {};
  final Map<String, String> _fontScheme = {};

  ThemeManager(Archive archive) {
    final themeFile = archive.findFile('word/theme/theme1.xml');
    if (themeFile == null) return;

    final themeContent = utf8.decode(themeFile.content as List<int>);
    final themeDoc = XmlDocument.parse(themeContent);

    _parseColorScheme(themeDoc);
    _parseFontScheme(themeDoc);
  }

  /// <a:clrScheme> element ko parse karke theme colors extract karta hai.
  void _parseColorScheme(XmlDocument document) {
    final clrScheme = document.findAllElements('a:clrScheme').firstOrNull;
    if (clrScheme == null) return;

    for (var element in clrScheme.children.whereType<XmlElement>()) {
      final colorName = element.name.local;
      final srgbClr = element.findElements('a:srgbClr').firstOrNull;
      final sysClr = element.findElements('a:sysClr').firstOrNull;

      final colorValue = srgbClr?.getAttribute('val') ?? sysClr?.getAttribute('lastClr');

      if (colorValue != null) {
        _colorScheme[colorName] = colorValue;
      }
    }
  }

  /// <a:fontScheme> element ko parse karke theme fonts extract karta hai.
  void _parseFontScheme(XmlDocument document) {
    final fontScheme = document.findAllElements('a:fontScheme').firstOrNull;
    if (fontScheme == null) return;

    final majorFont = fontScheme
        .findElements('a:majorFont')
        .firstOrNull
        ?.findElements('a:latin')
        .firstOrNull
        ?.getAttribute('typeface');

    final minorFont = fontScheme
        .findElements('a:minorFont')
        .firstOrNull
        ?.findElements('a:latin')
        .firstOrNull
        ?.getAttribute('typeface');
    
    if (majorFont != null) _fontScheme['majorFont'] = majorFont;
    if (minorFont != null) _fontScheme['minorFont'] = minorFont;
  }

  /// Theme name se color hex value retrieve karta hai (e.g., 'accent1').
  /// Agar specify kiya ho to tint (halka) ya shade (gehra) apply karta hai.
  String? getColor(String name, {String? tint, String? shade}) {
    final rawColor = _colorScheme[name];
    if (rawColor == null) return null;

    try {
      Color color = Color(int.parse('FF$rawColor', radix: 16));
      
      if (tint != null) {
        final tintValue = double.parse(tint) / 100000.0;
        final hsl = HSLColor.fromColor(color);
        color = hsl.withLightness(hsl.lightness + (1.0 - hsl.lightness) * tintValue).toColor();
      } else if (shade != null) {
        final shadeValue = double.parse(shade) / 100000.0;
        final hsl = HSLColor.fromColor(color);
        color = hsl.withLightness(hsl.lightness * (1.0 - shadeValue)).toColor();
      }
      
      return color.value.toRadixString(16).substring(2).toUpperCase();
    } catch(e) {
      return rawColor;
    }
  }

  /// Theme name ('majorFont' ya 'minorFont') se font family name retrieve karta hai.
  String? getFont(String name) {
    return _fontScheme[name];
  }
}
