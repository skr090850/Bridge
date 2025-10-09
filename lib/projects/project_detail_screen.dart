import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:intl/intl.dart'; 

import 'model/project_model.dart';
import 'model/folder_model.dart';
import 'model/file_model.dart';
import 'model/project_member_model.dart';

import 'viewers/doc_viewer_screen_using_api.dart';
import 'viewers/doc_viewer_screen.dart';
import 'viewers/pdf_viewer_screen.dart';
import 'viewers/epub_viewer_screen.dart';
import 'viewers/text_viewer_screen.dart';
import 'viewers/image_viewer_screen.dart';
import 'viewers/xlsx_viewer_screen.dart';
import 'viewers/epub_viewer_screen_copy_withzoom.dart';
import 'viewers/epub_viewer_withoutZoom.dart';

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytes, int totalBytes) onProgress;

  MultipartRequestWithProgress(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytes = 0;

    final stream = byteStream.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          bytes += data.length;
          onProgress(bytes, total);
          sink.add(data);
        },
      ),
    );

    return http.ByteStream(stream);
  }
}

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
  Future<List<ProjectMember>> _fetchProjectMembers(int projectId) async {
    final response = await http.get(Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/template/getmemberAssainersList?id=$projectId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ProjectMember.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load project members');
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
    // else if (extension == 'epub')
      // viewer = EpubViewerScreen(filePath: filePath, fileName: fileName);
      // viewer = EpubViewerScreenCopy(filePath: filePath, fileName: fileName);
    // viewer = EpubViewer(filePath: filePath, fileName: fileName);
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

  void _showUploadDialog() {
    List<File> selectedFiles = [];
    bool isUploading = false;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickFiles() async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (result != null) {
                setDialogState(() {
                  selectedFiles = result.paths
                      .map((path) => File(path!))
                      .toList();
                });
              }
            }

            Future<void> uploadFiles() async {
              setDialogState(() {
                isUploading = true;
              });

              var uri = Uri.parse(
                'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/PostUserImage',
              );
              final request = MultipartRequestWithProgress(
                'POST',
                uri,
                onProgress: (bytes, totalBytes) {
                  setDialogState(() {
                    if (totalBytes != 0) {
                      uploadProgress = bytes / totalBytes;
                    }
                  });
                },
              );

              final projid = widget.projectId.toString();
              final fid = _selectedFolder!.id.toString();
              final uid = '1000';

              // debugPrint('--- UPLOADING FILE ---');
              // debugPrint('API URL: $uri');
              // debugPrint('Project ID: $projid');
              // debugPrint('Folder ID: $fid');
              // debugPrint('User ID: $uid');

              request.fields['projid'] = projid;
              request.fields['fid'] = fid;
              request.fields['uid'] = uid;

              for (int i = 0; i < selectedFiles.length; i++) {
                // debugPrint('Adding file: ${selectedFiles[i].path.split('/').last}');
                request.files.add(
                  await http.MultipartFile.fromPath(
                    'file_${i + 1}',
                    selectedFiles[i].path,
                  ),
                );
              }

              try {
                var response = await request.send();
                final responseBody = await response.stream.bytesToString();

                // debugPrint('Response Status Code: ${response.statusCode}');
                // debugPrint('Response Body: $responseBody');
                // debugPrint('--- UPLOAD COMPLETE ---');

                if (response.statusCode == 200) {
                  final body = responseBody.trim();
                  if (body == '1' || body.isEmpty) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Files uploaded successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {
                        _filesFuture = _fetchFiles(
                          widget.projectId,
                          _selectedFolder!.id,
                        );
                      });
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('An unknown error occurred'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Upload failed. Server error: ${response.statusCode}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                // debugPrint('Upload Exception: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('An error occurred: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setDialogState(() {
                  isUploading = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              contentPadding: const EdgeInsets.all(24),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload File',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width * 0.8,
                  minWidth:
                      300,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: pickFiles,
                      child: DottedBorder(
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(8),
                        color: Colors.grey[400]!,
                        strokeWidth: 1.5,
                        dashPattern: const [6, 5],
                        child: Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: selectedFiles.isEmpty
                              ? Center(
                                  child: Text(
                                    'Please select files here',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Column(
                                      children: selectedFiles
                                          .map(
                                            (file) => ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.insert_drive_file,
                                                size: 20,
                                              ),
                                              title: Text(
                                                file.path.split('/').last,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: isUploading
                          ? Column(
                            children: [
                              LinearProgressIndicator(
                                value: uploadProgress,
                                backgroundColor: Colors.grey[300],
                              ),
                              const SizedBox(height: 8),
                              Text('${(uploadProgress * 100).toStringAsFixed(0)}% Uploaded'),
                            ],
                          )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: selectedFiles.isEmpty || isUploading
                                  ? null
                                  : uploadFiles,
                              child: const Text(
                                'Upload',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSendEmailDialog() {
    final textTheme = Theme.of(context).textTheme;
    final Future<List<ProjectMember>> membersFuture = _fetchProjectMembers(widget.projectId);
    final mailContentController = TextEditingController();
    List<ProjectMember> membersList = [];
    bool selectAll = false;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<void> sendEmail() async {
              final selectedIds = membersList.where((m) => m.isSelected).map((m) => m.id.toString()).toList();
              
              if (selectedIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one member.'), backgroundColor: Colors.orange));
                return;
              }
              if (mailContentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mail content cannot be empty.'), backgroundColor: Colors.orange));
                return;
              }

              setDialogState(() => isSending = true);

              try {
                final now = DateTime.now();
                final formattedDate = DateFormat('dd/MM/yyyy').format(now);

                final body = {
                  "MailFromId": 1000,
                  "fid": _selectedFolder?.id ?? 0,
                  "projectid": widget.projectId,
                  "MailSub": _selectedFolder?.name ?? widget.projectTitle,
                  "MailToids": selectedIds.join(','),
                  "MailMessage": mailContentController.text.trim(),
                  "MailPerson": null,
                  "createddate": formattedDate,
                  "processdate": formattedDate,
                  "Type": "Folders",
                  "MailEventId": 0,
                  "processid": null,
                  "status": 0
                };

                final response = await http.post(
                  Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/template/AddMailalerts'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(body),
                );

                // debugPrint('--- SEND EMAIL RESPONSE ---');
                // debugPrint('Status Code: ${response.statusCode}');
                // debugPrint('Response Body: ${response.body}');
                // debugPrint('--------------------------');

                if (response.statusCode == 200) {
                  final responseBody = json.decode(response.body);
                  if (responseBody == true) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sent successfully!'), backgroundColor: Colors.green));
                    }
                  } else {
                    throw Exception('Server returned false.');
                  }
                } else {
                  throw Exception('Server error: ${response.statusCode}');
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send email: $e'), backgroundColor: Colors.red));
              } finally {
                if (mounted) setDialogState(() => isSending = false);
              }
            }
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Send Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DottedBorder(
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(8),
                        color: Colors.grey[400]!,
                        strokeWidth: 1.5,
                        dashPattern: const [6, 5],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          width: double.infinity,
                          child: Text(
                            _selectedFolder?.name ?? widget.projectTitle,
                            style: TextStyle(color: Colors.grey[700])
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<ProjectMember>>(
                        future: membersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No members found.'));
                          }
                          
                          membersList = snapshot.data!;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CheckboxListTile(
                                title: Text('Select All Members',style: Theme.of(context).textTheme.labelLarge,),
                                value: selectAll,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    selectAll = value!;
                                    for (var member in membersList) {
                                      member.isSelected = selectAll;
                                    }
                                  });
                                },
                                visualDensity: const VisualDensity(vertical: -4),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              const Divider(),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: membersList.length,
                                itemBuilder: (context, index) {
                                  final member = membersList[index];
                                  return CheckboxListTile(
                                    title: Text(member.name,style: Theme.of(context).textTheme.labelLarge,),
                                    value: member.isSelected,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        member.isSelected = value!;
                                      });
                                    },
                                    visualDensity: const VisualDensity(vertical: -4),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: mailContentController,
                        style: textTheme.labelLarge,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Mail content',hintStyle: Theme.of( context).textTheme.labelLarge?.copyWith(color: Colors.grey[600]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isSending ? null : sendEmail,
                      child: isSending
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('Send', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
      appBar: AppBar(title: Text(widget.projectTitle),
      actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined),
            onPressed: _showSendEmailDialog,
          ),
        ],
      ),
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
          Expanded(flex: 1, child: _buildFolderGridView()),
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
                  style: textTheme.titleLarge?.copyWith(
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
                  title: Text(
                    project.coordinatorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${project.coordinatorPosition}\n${project.coordinatorOrganization}",
                  ),
                  // trailing: Icon(Icons.person,
                  //     color: Theme.of(context).colorScheme.primary),
                ),
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
                icon: const Icon(Icons.upload_file),
                onPressed:
                    _showUploadDialog,
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
                childAspectRatio: 1.6,  //before 1
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
                        maxLines: 1, //before 2
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
