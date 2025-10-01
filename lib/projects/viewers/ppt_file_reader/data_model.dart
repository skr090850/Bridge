import 'package:flutter/material.dart';

/// Represents a parsed PPTX presentation.
class PptxPresentation {
  final List<PptxSlide> slides;
  final Size slideSize;

  PptxPresentation({
    required this.slides,
    required this.slideSize,
  });
}

/// Represents a single slide in the presentation.
class PptxSlide {
  final List<Widget> children;
  final String? background; // Hex color value for background
  final List<Widget> notes;

  PptxSlide({
    required this.children,
    this.background,
    this.notes = const [],
  });
}

/// Represents the master layout for a set of slides.
class SlideMaster {
  final Map<String, SlideLayout> layouts;
  final String? background;

  SlideMaster({required this.layouts, this.background});
}

/// Represents a specific layout within a master.
class SlideLayout {
   final List<Widget> children;
   final String? background;

   SlideLayout({required this.children, this.background});
}

