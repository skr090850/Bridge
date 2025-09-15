import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'file_model.dart';
import 'pdf_viewer_screen.dart';
import 'epub_viewer_screen.dart';
import 'doc_viewer_screen.dart';
import 'text_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'xlsx_viewer_screen.dart';

class FileListScreen extends StatefulWidget {
  final int projectId;
  final int folderId;
  final String folderName;

  const FileListScreen(
      {super.key,
      required this.projectId,
      required this.folderId,
      required this.folderName});

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  late Future<List<FileModel>> _filesFuture;
  bool _isDownloading = false;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
    _filesFuture = _fetchAndFilterFiles(widget.projectId, widget.folderId);
  }

  Future<List<FileModel>> _fetchAndFilterFiles(
      int projectId, int folderId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/files?_projid=$projectId';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);
        List<dynamic> allFiles;
        if (decodedBody is String) {
          allFiles = json.decode(decodedBody);
        } else if (decodedBody is List) {
          allFiles = decodedBody;
        } else {
          throw Exception('Unexpected response format for files');
        }
        // Files ko folder ID se filter kiya hai
        final List<dynamic> filteredFiles =
            allFiles.where((file) => file['fid'] == folderId).toList();
        return filteredFiles.map((json) => FileModel.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load files. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('An error occurred while fetching files: $e');
      throw Exception('An error occurred while fetching file data.');
    }
  }

  Future<String?> _downloadFile(int fileId, String fileName) async {
    try {
      final url = Uri.parse(
          'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId');
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
            SnackBar(
                content:
                    Text('Failed to download file. Status: ${response.statusCode}')),
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

  Future<void> _handleFileTap(int fileId, String fileName) async {
    setState(() {
      _isDownloading = true;
      _downloadingFileName = fileName;
    });

    try {
      final filePath = await _downloadFile(fileId, fileName);
      if (filePath == null || !mounted) return;

      final extension = fileName.split('.').last.toLowerCase();
      const officeExtensions = ['doc', 'docx', 'pptx'];
      const imageExtensions = ['png', 'jpg', 'jpeg'];

      if (officeExtensions.contains(extension)) {
        final fileUrl =
            'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId';
        final encodedUrl = Uri.encodeComponent(fileUrl);
        final viewerUrl =
            'https://docs.google.com/gview?url=$encodedUrl&embedded=true';
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    DocViewerScreen(fileUrl: viewerUrl, fileName: fileName)));
        return;
      }

      Widget? viewer;
      if (extension == 'pdf') {
        viewer = PdfViewerScreen(filePath: filePath, fileName: fileName);
      } else if (extension == 'epub') {
        viewer = EpubViewerScreen(filePath: filePath, fileName: fileName);
      } else if (extension == 'txt') {
        viewer = TextViewerScreen(filePath: filePath, fileName: fileName);
      } else if (imageExtensions.contains(extension)) {
        viewer = ImageViewerScreen(filePath: filePath, fileName: fileName);
      } else if (extension == 'xlsx') {
        viewer = XlsxViewerScreen(filePath: filePath, fileName: fileName);
      }

      if (viewer != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => viewer!));
      } else {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
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

  Widget _getIconForFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    String imagePath;
    switch (extension) {
      case 'pdf':
        imagePath = 'assets/images/pdf.png';
        break;
      case 'doc':
      case 'docx':
        imagePath = 'assets/images/doc.png';
        break;
      case 'png':
        imagePath = 'assets/images/png.png';
      case 'jpg':
        imagePath = 'assets/images/jpg.png';
        break;
      case 'jpeg':
        imagePath = 'assets/images/jpeg.png';
        break;
      case 'svg':
        imagePath = 'assets/images/svg.png';
        break;
      case 'xlsx':
        imagePath = 'assets/images/xls.png';
        break;
      case 'pptx':
        imagePath = 'assets/images/ppt.png';
        break;
      case "epub":
        imagePath = 'assets/images/epub.png';
        break;
      case "txt":
        imagePath = 'assets/images/txt.png';
      default:
        imagePath = 'assets/images/pages.png';
    }
    return Image.asset(imagePath, width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
      ),
      body: FutureBuilder<List<FileModel>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No files found in this folder.'));
          } else {
            final files = snapshot.data!;
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isCurrentlyDownloading =
                    _isDownloading && _downloadingFileName == file.name;
                return ListTile(
                  leading: _getIconForFile(file.name),
                  title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis,),
                  subtitle: Text('Size: ${file.size}'),
                  trailing: isCurrentlyDownloading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3))
                      : null,
                  onTap: isCurrentlyDownloading
                      ? null
                      : () => _handleFileTap(file.id, file.name),
                );
              },
            );
          }
        },
      ),
    );
  }
}

