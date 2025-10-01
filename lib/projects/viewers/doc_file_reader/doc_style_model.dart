import 'package:flutter/material.dart';

/// Represents all possible styling attributes for text and paragraphs.
/// This class is immutable. Use the `merge` method to combine styles.
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
  final double? indentRight;
  final double? indentFirstLine;
  final double? indentHanging;
  final String? fontFamily;

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
    this.indentRight,
    this.indentFirstLine,
    this.indentHanging,
    this.fontFamily,
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
      indentRight: other.indentRight ?? indentRight,
      indentFirstLine: other.indentFirstLine ?? indentFirstLine,
      indentHanging: other.indentHanging ?? indentHanging,
      fontFamily: other.fontFamily ?? fontFamily,
    );
  }
}

