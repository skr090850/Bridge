import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// Extension to safely get the first element of an iterable or return null.
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Manages the definitions and state of numbered and bulleted lists.
class NumberingManager {
  // Storing a map of properties for each level for more robust handling
  final Map<String, Map<String, Map<String, String>>> _definitions = {};
  // Key: 'numId_level', Value: current count
  final Map<String, int> _counters = {};

  NumberingManager(Archive archive) {
    final numFile = archive.findFile('word/numbering.xml');
    if (numFile == null) return;

    final numContent = utf8.decode(numFile.content as List<int>);
    final numDoc = XmlDocument.parse(numContent);

    final abstractMap = <String, Map<String, Map<String, String>>>{};

    for (final abstractNum in numDoc.findAllElements('w:abstractNum')) {
      final abstractNumId = abstractNum.getAttribute('w:abstractNumId');
      if (abstractNumId == null) continue;

      final levelFormats = <String, Map<String, String>>{};
      for (final lvlElement in abstractNum.findAllElements('w:lvl')) {
        final ilvl = lvlElement.getAttribute('w:ilvl');
        final numFmt =
            lvlElement.findElements('w:numFmt').firstOrNull?.getAttribute('w:val');
        final lvlText =
            lvlElement.findElements('w:lvlText').firstOrNull?.getAttribute('w:val');
        
        if (ilvl != null && numFmt != null && lvlText != null) {
          levelFormats[ilvl] = {'fmt': numFmt, 'text': lvlText};
        }
      }
      abstractMap[abstractNumId] = levelFormats;
    }

    for (final numElement in numDoc.findAllElements('w:num')) {
      final numId = numElement.getAttribute('w:numId');
      final abstractNumId = numElement
          .findElements('w:abstractNumId')
          .firstOrNull
          ?.getAttribute('w:val');
      if (numId != null &&
          abstractNumId != null &&
          abstractMap.containsKey(abstractNumId)) {
        _definitions[numId] = abstractMap[abstractNumId]!;
      }
    }
  }
  
  String getBulletText(String numId, String level) {
    final currentLevel = int.tryParse(level) ?? 0;

    // Reset counters for deeper levels
    for (var i = currentLevel + 1; i < 9; i++) {
      _counters['${numId}_$i'] = 0;
    }

    final key = '${numId}_$level';
    _counters[key] = (_counters[key] ?? 0) + 1;
    
    final levelInfo = _definitions[numId]?[level];
    if (levelInfo == null) return '•'; // Default bullet

    final numFmt = levelInfo['fmt']!;
    var formatText = levelInfo['text']!;

    if (numFmt == 'bullet') {
      return formatText; // The text itself is the bullet
    }
    
    // Replace placeholders like %1, %2, etc.
    for (var i = 0; i <= currentLevel; i++) {
        final count = _counters['${numId}_$i'] ?? 1;
        final levelFmt = _definitions[numId]?['$i']?['fmt'] ?? 'decimal';
        String replacement = _getNumberString(levelFmt, count);
        formatText = formatText.replaceAll('%${i+1}', replacement);
    }
    
    return formatText;
  }

  /// Converts a number to its string representation based on format, WITHOUT punctuation.
  String _getNumberString(String numFmt, int count) {
    switch (numFmt) {
      case 'decimal':
        return count.toString();
      case 'decimalZero':
        return count.toString().padLeft(2, '0');
      case 'lowerLetter':
        return String.fromCharCode('a'.codeUnitAt(0) + count - 1);
      case 'upperLetter':
        return String.fromCharCode('A'.codeUnitAt(0) + count - 1);
      case 'lowerRoman':
        return _toRoman(count).toLowerCase();
      case 'upperRoman':
        return _toRoman(count);
      default:
        return count.toString();
    }
  }

  String _toRoman(int number) {
    if (number < 1 || number > 3999) return number.toString();
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];
    var result = '';
    for (var i = 0; i < values.length; i++) {
      while (number >= values[i]) {
        number -= values[i];
        result += numerals[i];
      }
    }
    return result;
  }
}

