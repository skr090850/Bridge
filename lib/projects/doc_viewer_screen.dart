import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    // try {
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
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
          }
        ),
      )
      // ..loadRequest(Uri.parse("http://183.82.115.221/Bridge/BridgeApi/Content/EPC_doc.docx"));
      ..loadRequest(Uri.parse(widget.fileUrl));
      // } catch (e) {
        // print("Error initializing WebView: $e");
      // Ignore if not on Android
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: const Color(0xFF00A3D7),
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
