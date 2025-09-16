import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_html/flutter_html.dart';

import 'model/project_model.dart';
import 'model/folder_model.dart';
import 'model/file_model.dart';

import 'viewers/doc_viewer_screen.dart';
import 'viewers/pdf_viewer_screen.dart';
import 'viewers/epub_viewer_screen.dart';
import 'viewers/text_viewer_screen.dart';
import 'viewers/image_viewer_screen.dart';
import 'viewers/xlsx_viewer_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<Project> _projectDetailsFuture;
  late Future<List<Folder>> _foldersFuture;
  Future<List<FileModel>>? _filesFuture;
  Folder? _selectedFolder;

  bool _isDownloading = false;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
    _projectDetailsFuture = _fetchProjectDetails(widget.projectId);
    _foldersFuture = _fetchFolders(widget.projectId);
  }

  Future<Project> _fetchProjectDetails(int projectId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/getproject?projid=$projectId';
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final dynamic body = json.decode(response.body);
      final Map<String, dynamic> data = body is String
          ? json.decode(body)
          : body;
      return Project.fromJson(data);
    } else {
      throw Exception('Failed to load project details');
    }
  }

  Future<List<Folder>> _fetchFolders(int projectId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/GetprojFolders?tid=1&projid=$projectId';
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final dynamic body = json.decode(response.body);
      final List<dynamic> data = body is String ? json.decode(body) : body;
      return data.map((json) => Folder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load folders');
    }
  }

  Future<List<FileModel>> _fetchFiles(int projectId, int folderId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/files?_projid=$projectId';
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final dynamic body = json.decode(response.body);
      final List<dynamic> allFiles = body is String ? json.decode(body) : body;
      final List<dynamic> filtered = allFiles
          .where((file) => file['fid'] == folderId)
          .toList();
      return filtered.map((json) => FileModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load files');
    }
  }

  Future<void> _handleFileTap(int fileId, String fileName) async {
    setState(() {
      _isDownloading = true;
      _downloadingFileName = fileName;
    });
    try {
      final url = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId',
      );
      final response = await http.get(url);
      if (response.statusCode != 200)
        throw Exception('Download failed with status: ${response.statusCode}');

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;
      _openFile(filePath, fileName, fileId);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error handling file: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isDownloading = false;
          _downloadingFileName = '';
        });
    }
  }

  void _openFile(String filePath, String fileName, int fileId) {
    final extension = fileName.split('.').last.toLowerCase();
    const officeExtensions = ['doc', 'docx', 'pptx'];
    const imageExtensions = ['png', 'jpg', 'jpeg'];

    if (officeExtensions.contains(extension)) {
      final fileUrl =
          'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/GetpdfData?id=$fileId';
      final viewerUrl =
          'https://docs.google.com/gview?url=${Uri.encodeComponent(fileUrl)}&embedded=true';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DocViewerScreen(fileUrl: viewerUrl, fileName: fileName),
        ),
      );
      return;
    }

    Widget? viewer;
    if (extension == 'pdf')
      viewer = PdfViewerScreen(filePath: filePath, fileName: fileName);
    else if (extension == 'epub')
      viewer = EpubViewerScreen(filePath: filePath, fileName: fileName);
    else if (extension == 'txt')
      viewer = TextViewerScreen(filePath: filePath, fileName: fileName);
    else if (imageExtensions.contains(extension))
      viewer = ImageViewerScreen(filePath: filePath, fileName: fileName);
    else if (extension == 'xlsx')
      viewer = XlsxViewerScreen(filePath: filePath, fileName: fileName);

    if (viewer != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => viewer!));
    } else {
      OpenFilex.open(filePath).then((result) {
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      });
    }
  }

  Widget _getIconForFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    String imagePath;
    switch (extension) {
      case 'pdf':
        imagePath = 'assets/images/pdf.png';
        break;
      case 'txt':
        imagePath = 'assets/images/txt.png';
        break;
      case 'doc':
      case 'docx':
        imagePath = 'assets/images/doc.png';
        break;
      case 'png':
        imagePath = 'assets/images/png.png';
        break;
      case 'jpg':
        imagePath = 'assets/images/jpg.png';
        break;
      case 'jpeg':
        imagePath = 'assets/images/jpeg.png';
        break;
      case 'xlsx':
        imagePath = 'assets/images/xls.png';
        break;
      case 'pptx':
        imagePath = 'assets/images/ppt.png';
        break;
      case "epub":
        imagePath = 'assets/images/epub.png';
      default:
        imagePath = 'assets/images/pages.png';
    }
    return Image.asset(
      imagePath,
      width: 24,
      height: 24,
      errorBuilder: (c, e, s) => Icon(
        Icons.insert_drive_file,
        size: 24,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectTitle)),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedFolder == null
                  ? _buildProjectDetailsView()
                  : _buildFileListView(),
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildFolderGridView(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetailsView() {
    return FutureBuilder<Project>(
      key: const ValueKey('projectDetails'),
      future: _projectDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("No project details found."));
        }
        final project = snapshot.data!;
        final textTheme = Theme.of(context).textTheme;
        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style:textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  // style: const TextStyle(
                  //     fontSize: 24, fontWeight: FontWeight.bold),

                ),
                
                const SizedBox(height: 8),
                Html(data: project.projectDesc),
                const Divider(height: 32, thickness: 1),
                // const Text(
                //   'Coordinator Details',
                //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                // ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(project.coordinatorName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "${project.coordinatorPosition}\n${project.coordinatorOrganization}"),
                  // trailing: Icon(Icons.person,
                  //     color: Theme.of(context).colorScheme.primary),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileListView() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: ValueKey(_selectedFolder!.id),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Icon(Icons.folder_open, color: Colors.grey[700], size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedFolder!.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  // style: const TextStyle(
                  //   fontSize: 20,
                  //   fontWeight: FontWeight.bold,
                  // ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedFolder = null;
                    _filesFuture = null;
                  });
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey[200],
          child: Row(
            children: [
              const SizedBox(width: 40),
              const Expanded(
                flex: 5,
                child: Text(
                  'Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Size',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Date',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FileModel>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No files found in this folder.'),
                );
              } else {
                final files = snapshot.data!;
                return ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isCurrentlyDownloading =
                        _isDownloading && _downloadingFileName == file.name;
                    return InkWell(
                      onTap: isCurrentlyDownloading
                          ? null
                          : () => _handleFileTap(file.id, file.name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          children: [
                            _getIconForFile(file.name),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Text(
                                file.name,
                                style: textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                file.size,
                                style: textTheme.bodySmall,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                            flex: 3,
                            child: isCurrentlyDownloading
                                ? const Align(
                                    alignment: Alignment.centerRight,
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : Text(
                                    file.dateModified,
                                    style: textTheme.bodySmall,
                                    textAlign: TextAlign.right,
                                  ),
                          ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFolderGridView() {
    return Container(
      // height: 400,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: FutureBuilder<List<Folder>>(
        future: _foldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No folders found.'));
          } else {
            final folders = snapshot.data!;
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFolder = folder;
                      _filesFuture = _fetchFiles(widget.projectId, folder.id);
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 35,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        folder.name,
                        style: Theme.of(context).textTheme.labelMedium,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
