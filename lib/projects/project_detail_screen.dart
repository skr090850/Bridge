import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'pdf_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import 'doc_viewer_screen.dart';
import 'text_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'xlsx_viewer_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<List<Map<String, dynamic>>> _filesFuture;
  String _folderName = 'Loading...';
  int _folderId = 0;
  bool _isDownloading = false;
  String _downloadingFileName = '';

  // final Map<int, String> _googleDriveLinks = {
  //   1: "https://docs.google.com/presentation/d/11ikoMaaSqqkxNAYCb3lgbQHi9pAvgkF6/preview",
  //   1007: "https://docs.google.com/document/d/1gN5w_0vx0f8l1TWHs0aaMZ8THQKfM1oV/preview",
  //   2012: "https://docs.google.com/spreadsheets/d/1xAZxcIQfLE570Fb4j6DZar5JWvcCX-O9/pubhtml?widget=true&amp;headers=false"
  // };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _folderId = arguments['id'];
      _folderName = arguments['name'];
      _filesFuture = _fetchAndFilterFiles(_folderId);
    } else {
      _filesFuture = Future.error("Could not load folder data.");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndFilterFiles(int folderId) async {
    const String apiUrl = 'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/files?_projid=4';
    debugPrint('Fetching files for folder ID: $folderId from $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw 'Request timed out. Please check your internet connection.';
        },
      );
      
      debugPrint('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> allFiles = json.decode(response.body);
        final List<dynamic> filteredFiles = allFiles.where((file) => file['fid'] == folderId).toList();
        debugPrint('Found ${filteredFiles.length} files for this folder.');
        return filteredFiles.cast<Map<String, dynamic>>().toList();
      } else {
        throw Exception('Failed to load files. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('An error occurred while fetching files: $e');
      throw Exception('An error occurred: $e');
    }
  }

  Future<void> _handleFileTap(int fileId, String fileName) async {
    setState(() {
      _isDownloading = true;
      _downloadingFileName = fileName;
    });

    try {
      // if (_googleDriveLinks.containsKey(fileId)) {
      //   final url = _googleDriveLinks[fileId]!;
      //   if (mounted) {
      //     Navigator.push(context, MaterialPageRoute(builder: (context) =>
      //       DocViewerScreen(fileUrl: url, fileName: fileName),
      //     ));
      //   }
      //   return;
      // }

      final filePath = await _downloadFile(fileId, fileName);
      if (filePath == null) return;

      final extension = fileName.split('.').last.toLowerCase();
      const officeExtensions = ['doc', 'docx', 'pptx'];
      const imageExtensions = ['png', 'jpg', 'jpeg'];

      if (officeExtensions.contains(extension)) {
        final fileUrl = 'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId';
        final encodedUrl = Uri.encodeComponent(fileUrl);
        final viewerUrl = 'https://docs.google.com/gview?url=$encodedUrl&embedded=true';

        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            DocViewerScreen(fileUrl: viewerUrl, fileName: fileName),
          ));
        }
        return;
      }

      if (mounted) {
        if (extension == 'pdf') {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            PdfViewerScreen(filePath: filePath, fileName: fileName),
          ));
        } else if (extension == 'epub') {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            EpubViewerScreen(filePath: filePath, fileName: fileName),
            // EpubViewerScreen(filePath: filePath),
          ));
        } else if (extension == 'txt') {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            TextViewerScreen(filePath: filePath, fileName: fileName),
          ));
        } else if (imageExtensions.contains(extension)) {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            ImageViewerScreen(filePath: filePath, fileName: fileName),
          ));
        }else if (extension == 'xlsx') {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>
            XlsxViewerScreen(filePath: filePath, fileName: fileName),
          ));
        }
        else {
          final result = await OpenFilex.open(filePath);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingFileName = '';
        });
      }
    }
  }

  Future<String?> _downloadFile(int fileId, String fileName) async {
    try {
      final url = Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download file. Status: ${response.statusCode}')),
          );
        }
        return null;
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download Error: $e')),
          );
        }
        return null;
    }
  }

  IconData _getIconForFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'png': case 'jpg': case 'jpeg': return Icons.image; // Icon already tha
      case 'xlsx': return Icons.table_chart;
      case 'pptx': return Icons.slideshow;
      case 'epub': return Icons.book;
      case 'txt': return Icons.article; // NAYA ICON
      default: return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_folderName),
        backgroundColor: const Color(0xFF00A3D7),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No files found in this folder.'));
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileId = file['pffid'];
                final fileName = file['filename'] ?? 'Unnamed File';
                final fileSize = file['filesize'] ?? 0;

                final isCurrentlyDownloading = _isDownloading && _downloadingFileName == fileName;

                return ListTile(
                  leading: Icon(_getIconForFile(fileName), color: const Color(0xFF00A3D7), size: 40),
                  title: Text(fileName),
                  subtitle: Text('Size: ${_formatFileSize(fileSize)}'),
                  trailing: isCurrentlyDownloading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                      : null,
                  onTap: _isDownloading ? null : () {
                    if (fileId != null) {
                      _handleFileTap(fileId, fileName);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: File ID is missing.'))
                      );
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

