import 'package:flutter/widgets.dart';

/// Ek parse kiye gaye DOCX document ko represent karta hai.
///
/// Yeh class main body, headers, aur footers ke content ko hold karti hai.
class DocxDocument {
  final List<Widget> headers;
  final List<Widget> body;
  final List<Widget> footers;

  DocxDocument({
    required this.headers,
    required this.body,
    required this.footers,
  });
}
