import 'dart:io';
import 'package:flutter/material.dart';

class TextViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const TextViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  String _fileContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _readFileContent();
  }

  Future<void> _readFileContent() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _fileContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileContent = 'Error reading file: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(_fileContent),
            ),
    );
  }
}
