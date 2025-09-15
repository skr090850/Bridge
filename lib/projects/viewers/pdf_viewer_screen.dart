import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: const Color(0xFF00A3D7),
      ),
      body: SfPdfViewer.file(
        File(filePath),
      ),
    );
  }
}
