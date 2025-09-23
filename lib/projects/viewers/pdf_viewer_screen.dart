import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadLastPage();
  }

  Future<void> _loadLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt('last_page_${widget.filePath}');
      if (lastPage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pdfViewerController.jumpToPage(lastPage);
        });
      }
    } catch (e) {
      debugPrint("Failed to load last visited page for PDF: $e");
    }
  }

  Future<void> _saveCurrentPage(int page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_page_${widget.filePath}', page);
    } catch (e) {
      debugPrint("Failed to save current page for PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        onPageChanged: (PdfPageChangedDetails details) {
          _saveCurrentPage(details.newPageNumber);
        },
      ),
    );
  }
}
