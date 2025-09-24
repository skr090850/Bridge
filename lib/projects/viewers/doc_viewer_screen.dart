import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const DocViewerScreen({super.key, required this.fileUrl, required this.fileName});

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  String get _storageKey => 'scroll_pos_${widget.fileUrl}';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _loadAndScrollToSavedPosition();
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load page: ${error.description}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.fileUrl));
  }

  Future<void> _loadAndScrollToSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final double position = prefs.getDouble(_storageKey) ?? 0.0;

      if (position > 0) {
        _controller.runJavaScript('window.scrollTo(0, $position);');
      }
    } catch (e) {
      debugPrint("Error loading scroll position: $e");
    }
  }

  Future<void> _saveScrollPosition() async {
    try {
      final scrollY = await _controller.runJavaScriptReturningResult('window.scrollY');
      final double position = double.tryParse(scrollY.toString()) ?? 0.0;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_storageKey, position);
    } catch (e) {
       debugPrint("Error saving scroll position: $e");
    }
  }

  @override
  void dispose() {
    _saveScrollPosition(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}