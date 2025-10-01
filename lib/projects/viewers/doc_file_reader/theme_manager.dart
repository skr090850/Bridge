import 'dart:convert';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

// Helper to safely get the first element of an iterable or return null.
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Manages parsing and providing theme-specific information.
class ThemeManager {
  final Map<String, String> _colorScheme = {};
  final Map<String, String> _fontScheme = {};

  ThemeManager(Archive archive, {String themePath = 'word/theme/theme1.xml'}) {
    final themeFile = archive.findFile(themePath);
    if (themeFile == null) return;

    final themeContent = utf8.decode(themeFile.content as List<int>);
    final themeDoc = XmlDocument.parse(themeContent);

    _parseColorScheme(themeDoc);
    _parseFontScheme(themeDoc);
  }

  /// Parses the <a:clrScheme> element to extract theme colors.
  void _parseColorScheme(XmlDocument document) {
    final clrScheme = document.findAllElements('a:clrScheme').firstOrNull;
    if (clrScheme == null) return;

    for (var element in clrScheme.children.whereType<XmlElement>()) {
      final colorName = element.name.local;
      final srgbClr = element.findElements('a:srgbClr').firstOrNull;
      final sysClr = element.findElements('a:sysClr').firstOrNull;

      final colorValue =
          srgbClr?.getAttribute('val') ?? sysClr?.getAttribute('lastClr');

      if (colorValue != null) {
        _colorScheme[colorName] = colorValue;
      }
    }
  }

  /// Parses the <a:fontScheme> element to extract theme fonts.
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

  /// Retrieves a color hex value by its theme name (e.g., 'accent1').
  /// Applies tint (lightening) or shade (darkening) if specified.
  String? getColor(String name, {String? tint, String? shade}) {
    final rawColor = _colorScheme[name];
    if (rawColor == null) return null;

    try {
      Color color = Color(int.parse('FF$rawColor', radix: 16));

      if (tint != null) {
        final tintValue = double.parse(tint) / 100000.0;
        final hsl = HSLColor.fromColor(color);
        color = hsl
            .withLightness(hsl.lightness + (1.0 - hsl.lightness) * tintValue)
            .toColor();
      } else if (shade != null) {
        final shadeValue = double.parse(shade) / 100000.0;
        final hsl = HSLColor.fromColor(color);
        color =
            hsl.withLightness(hsl.lightness * (1.0 - shadeValue)).toColor();
      }

      return color.value.toRadixString(16).substring(2).toUpperCase();
    } catch (e) {
      return rawColor;
    }
  }

  /// Retrieves a font family name by its theme name ('majorFont' or 'minorFont').
  String? getFont(String name) {
    return _fontScheme[name];
  }
}

