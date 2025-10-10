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
import '../members/user_project_model.dart';

import 'viewers/doc_viewer_screen_using_api.dart';
import 'viewers/doc_viewer_screen.dart';
import 'viewers/pdf_viewer_screen.dart';
import 'viewers/epub_viewer_screen.dart';
import 'viewers/text_viewer_screen.dart';
import 'viewers/image_viewer_screen.dart';
import 'viewers/xlsx_viewer_screen.dart';
import 'viewers/epub_viewer_screen_copy_withzoom.dart';
import 'viewers/doc_file_reader/word_doc_viewer_screen.dart';
import 'viewers/ppt_file_reader/viewer_screen.dart';

// import 'viewers/epub_viewer_withoutZoom.dart';
class FileLog {
  final String fileName;
  final int lastPage;
  final String folderName;
  FileLog({
    required this.fileName,
    required this.lastPage,
    required this.folderName,
  });
}

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

class ProjectDetailScreenExpansionPannel extends StatefulWidget {
  final int projectId;
  final String projectTitle;
  final int userId;

  const ProjectDetailScreenExpansionPannel({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.userId,
  });

  @override
  State<ProjectDetailScreenExpansionPannel> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState
    extends State<ProjectDetailScreenExpansionPannel> {
  late Future<List<Folder>> _foldersFuture;
  int? _projectCoordinatorId;
  bool _isLoadingProjectDetails = true;
  int? _expandedFolderId;
  List<FileModel> _currentFiles = [];
  bool _isLoadingFiles = false;
  List<Folder> _folderList = [];

  bool _isDownloading = false;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _foldersFuture = _fetchFolders(widget.projectId);
  }

  Future<void> _loadInitialData() async {
    try {
      await _fetchProjectDetails();
      _foldersFuture = _fetchFolders(widget.projectId);
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjectDetails = false;
        });
      }
    }
  }

  Future<void> _fetchProjectDetails() async {
    final response = await http.get(
      Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/getproject?projid=${widget.projectId}',
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _projectCoordinatorId = data['coordinaterid'];
        });
      }
    } else {
      throw Exception('Failed to load project details');
    }
  }

  void _showUserLogsDrawer() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final List<Color> avatarColors = [
          Colors.blue,
          Colors.green,
          Colors.red,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.pink,
          Colors.indigo,
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a Member to View Logs',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Flexible(
                child: FutureBuilder<List<ProjectMember>>(
                  future: _fetchProjectMembers(widget.projectId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final members = snapshot.data!;

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final color =
                            avatarColors[member.name.hashCode %
                                avatarColors.length];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            foregroundColor: color,
                            child: const Icon(Icons.person, size: 24),
                            // child: Text(
                            //   member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                            //   style: const TextStyle(fontWeight: FontWeight.bold),
                            // ),
                          ),
                          title: Text(member.name),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showUserActivityPopup(member.id, member.name);
                          },
                        );
                      },
                      separatorBuilder: (context, index) {
                        return const Divider(height: 1);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserActivityPopup(int memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Activity for $memberName"),
          content: SizedBox(
            width: double.maxFinite,
            child: UserActivityLog(
              userId: memberId,
              projectId: widget.projectId,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Folder>> _fetchFolders(int projectId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/GetprojFolders?tid=1&projid=$projectId';
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final dynamic body = json.decode(response.body);
      final List<dynamic> data = body is String ? json.decode(body) : body;
      final folders = data.map((json) => Folder.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _folderList = folders;
        });
      }
      return folders;
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
    final response = await http.get(
      Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/template/getmemberAssainersList?id=$projectId',
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ProjectMember.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load project members');
    }
  }

  Future<void> _handleFolderTap(int folderId) async {
    if (_expandedFolderId == folderId) {
      setState(() {
        _expandedFolderId = null;
        _currentFiles = [];
      });
      return;
    }

    setState(() {
      _expandedFolderId = folderId;
      _isLoadingFiles = true;
      _currentFiles = [];
    });

    try {
      final files = await _fetchFiles(widget.projectId, folderId);
      if (mounted && _expandedFolderId == folderId) {
        setState(() {
          _currentFiles = files;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFiles = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      }
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
      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;
      _openFile(filePath, fileName, fileId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error handling file: $e')));
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

  void _openFile(String filePath, String fileName, int fileId) {
    final extension = fileName.split('.').last.toLowerCase();
    const officeExtensions = ['doc', 'docx', 'pptx'];
    // const officeExtensions = ['pptx'];
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
    if (extension == 'pdf') {
      viewer = PdfViewerScreen(
        filePath: filePath,
        fileName: fileName,
        userId: widget.userId,
        fileId: fileId,
      );
    } else if (extension == 'epub') {
      viewer = EpubViewerScreenCopy(
        filePath: filePath,
        fileName: fileName,
        userId: widget.userId,
        fileId: fileId,
      );
    } else if (extension == 'txt') {
      viewer = TextViewerScreen(
        filePath: filePath,
        fileName: fileName,
        userId: widget.userId,
        fileId: fileId,
      );
    } else if (imageExtensions.contains(extension)) {
      viewer = ImageViewerScreen(filePath: filePath, fileName: fileName);
    } else if (extension == 'xlsx') {
      viewer = XlsxViewerScreen(
        filePath: filePath,
        fileName: fileName,
        userId: widget.userId,
        fileId: fileId,
      );
      // } else if (extension == 'docx' || extension == 'doc') {
      //   viewer = WordDocViewerScreen(filePath: filePath, fileName: fileName, userId: widget.userId,fileId: fileId,);
      // } else if (extension == 'pptx' || extension == 'ppt') {
      //   viewer = PptxViewerScreen(filePath: filePath, fileName: fileName, userId: widget.userId,fileId: fileId,);
    }

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

  // --- Dialogs ---

  void _showUploadDialog() {
    if (_expandedFolderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a folder first.')),
      );
      return;
    }

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
                uploadProgress = 0.0;
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
              final fid = _expandedFolderId.toString();
              final uid = widget.userId.toString();

              request.fields['projid'] = projid;
              request.fields['fid'] = fid;
              request.fields['uid'] = uid;

              for (int i = 0; i < selectedFiles.length; i++) {
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

                if (response.statusCode == 200) {
                  final body = responseBody.trim().replaceAll('"', '');

                  if (body == '1' || body.isEmpty) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Files uploaded successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      if (_expandedFolderId != null) {
                        _handleFolderTap(_expandedFolderId!);
                      }
                    }
                  } else {
                    throw Exception(
                      'Upload failed: ${body.isNotEmpty ? body : "Unknown server error"}',
                    );
                  }
                } else {
                  throw Exception(
                    'Upload failed. Server error: ${response.statusCode}',
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) {
                  setDialogState(() {
                    isUploading = false;
                  });
                }
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
              content: SizedBox(
                // constraints: BoxConstraints(
                width: MediaQuery.of(context).size.width * 0.9,
                // minWidth: 300,
                // ),
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
                                Text(
                                  '${(uploadProgress * 100).toStringAsFixed(0)}% Uploaded',
                                ),
                              ],
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
    final Future<List<ProjectMember>> membersFuture = _fetchProjectMembers(
      widget.projectId,
    );
    final mailContentController = TextEditingController();
    List<ProjectMember> membersList = [];
    bool selectAll = false;
    bool isSending = false;

    String emailSubject = widget.projectTitle;
    if (_expandedFolderId != null) {
      final selectedFolder = _folderList.firstWhere(
        (f) => f.id == _expandedFolderId,
        orElse: () => Folder(id: 0, name: '', description: ''),
      );
      if (selectedFolder.id != 0) {
        emailSubject = selectedFolder.name;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendEmail() async {
              final selectedIds = membersList
                  .where((m) => m.isSelected)
                  .map((m) => m.id.toString())
                  .toList();

              if (selectedIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select at least one member.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              if (mailContentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mail content cannot be empty.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              setDialogState(() => isSending = true);

              try {
                final now = DateTime.now();
                final formattedDate = DateFormat('dd/MM/yyyy').format(now);

                final body = {
                  "MailFromId": widget.userId,
                  "fid": _expandedFolderId ?? 0,
                  "projectid": widget.projectId,
                  "MailSub": emailSubject,
                  "MailToids": selectedIds.join(','),
                  "MailMessage": mailContentController.text.trim(),
                  "MailPerson": null,
                  "createddate": formattedDate,
                  "processdate": formattedDate,
                  "Type": "Folders",
                  "MailEventId": 0,
                  "processid": null,
                  "status": 0,
                };

                final response = await http.post(
                  Uri.parse(
                    'http://183.82.115.221/Bridge/BridgeApi/api/template/AddMailalerts',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(body),
                );

                if (response.statusCode == 200) {
                  final responseBody = json.decode(response.body);
                  if (responseBody == true) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email sent successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    throw Exception('Server returned false.');
                  }
                } else {
                  throw Exception('Server error: ${response.statusCode}');
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send email: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              } finally {
                if (mounted) setDialogState(() => isSending = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Send Email',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          width: double.infinity,
                          child: Text(
                            emailSubject,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<ProjectMember>>(
                        future: membersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text('No members found.'),
                            );
                          }

                          membersList = snapshot.data!;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CheckboxListTile(
                                title: Text(
                                  'Select All Members',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                value: selectAll,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    selectAll = value!;
                                    for (var member in membersList) {
                                      member.isSelected = selectAll;
                                    }
                                  });
                                },
                                visualDensity: const VisualDensity(
                                  vertical: -4,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
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
                                    title: Text(
                                      member.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    value: member.isSelected,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        member.isSelected = value!;
                                      });
                                    },
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
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
                          hintText: 'Mail content',
                          hintStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSending ? null : sendEmail,
                      child: isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
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

  // --- Helper Widgets ---

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
        break;
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
    final bool canViewLogs =
        (widget.userId == 1000 || widget.userId == _projectCoordinatorId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined),
            onPressed: _showSendEmailDialog,
            tooltip: 'Send Email',
          ),
          if (canViewLogs)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showUserLogsDrawer,
              tooltip: 'User Logs',
            ),
          if (_expandedFolderId != null)
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Upload to selected folder',
              onPressed: _showUploadDialog,
            ),
        ],
      ),
      // body: _buildFoldersAndFilesList(),
      body: _isLoadingProjectDetails
          ? const Center(child: CircularProgressIndicator())
          : _buildFoldersAndFilesList(),
    );
  }

  /// Builds the main UI: a list of expandable folders.
  Widget _buildFoldersAndFilesList() {
    return FutureBuilder<List<Folder>>(
      future: _foldersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No folders found.'));
        }

        final folders = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: folders.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final folder = folders[index];
            final isExpanded = folder.id == _expandedFolderId;

            return Column(
              children: [
                ListTile(
                  leading: Icon(
                    isExpanded ? Icons.folder_open : Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  title: Text(
                    folder.name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    // style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => _handleFolderTap(folder.id),
                ),
                // Animated container for displaying files
                AnimatedCrossFade(
                  firstChild: Container(), // Collapsed state
                  secondChild: _buildExpandedFilesView(), // Expanded state
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the view for the files inside an expanded folder.
  Widget _buildExpandedFilesView() {
    if (_isLoadingFiles) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentFiles.isEmpty) {
      return Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: const Center(child: Text('No files found in this folder.')),
      );
    }

    return Container(
      color: Colors.blue.withOpacity(0.04),
      child: Column(
        children: [
          // Header Row for files
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 40), // For icon alignment
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Size',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Generate file rows from the _currentFiles list
          ..._currentFiles.map((file) => _buildFileRow(file)).toList(),
        ],
      ),
    );
  }

  Widget _buildFileRow(FileModel file) {
    final isCurrentlyDownloading =
        _isDownloading && _downloadingFileName == file.name;

    return InkWell(
      onTap: isCurrentlyDownloading
          ? null
          : () => _handleFileTap(file.id, file.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            _getIconForFile(file.name),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                file.size,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
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
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Text(
                      file.dateModified,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserActivityLog extends StatefulWidget {
  final int userId;
  final int projectId;
  const UserActivityLog({
    super.key,
    required this.userId,
    required this.projectId,
  });

  @override
  State<UserActivityLog> createState() => _UserActivityLogState();
}

class _UserActivityLogState extends State<UserActivityLog> {
  late Future<List<FileLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchUserActivityLogs(widget.userId, widget.projectId);
  }

  Future<List<FileLog>> _fetchUserActivityLogs(
    int userId,
    int projectId,
  ) async {
    final List<FileLog> userLogs = [];

    // 1. Sirf current project ke folders fetch karein
    final foldersResponse = await http.get(
      Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/GetprojFolders?tid=1&projid=$projectId',
      ),
    );
    if (foldersResponse.statusCode != 200)
      throw Exception('Failed to load folders');

    final dynamic foldersBody = json.decode(foldersResponse.body);
    final List<dynamic> foldersData = foldersBody is String
        ? json.decode(foldersBody)
        : foldersBody;
    final List<Folder> folders = foldersData
        .map((json) => Folder.fromJson(json))
        .toList();

    // 2. Sirf current project ki files fetch karein
    final filesResponse = await http.get(
      Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/Bridge/files?_projid=$projectId',
      ),
    );
    if (filesResponse.statusCode != 200)
      throw Exception('Failed to load files');

    final List<dynamic> allFiles = json.decode(filesResponse.body);

    // 3. Har file ka status check karein aur folder ka naam pata karein
    for (var fileJson in allFiles) {
      FileModel file = FileModel.fromJson(fileJson);
      final statusResponse = await http.get(
        Uri.parse(
          'http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetFileReadingStatus?uid=$userId&fileid=${file.id}',
        ),
      );

      if (statusResponse.statusCode == 200) {
        final statusData = json.decode(statusResponse.body);
        if (statusData['status'] == true && statusData['currentPage'] != null) {
          // Folder ka naam dhoondhein
          final folder = folders.firstWhere(
            (f) => f.id == file.folderId,
            orElse: () =>
                Folder(id: 0, name: 'Unknown Folder', description: ''),
          );

          userLogs.add(
            FileLog(
              fileName: file.name,
              lastPage: statusData['currentPage'],
              folderName: folder.name,
            ),
          );
        }
      }
    }
    return userLogs;
  }

  @override
  Widget build(BuildContext context) {
    const double smallContainerHeight = 120.0;
    final double maxContainerHeight = MediaQuery.of(context).size.height * 0.5;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<FileLog>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: smallContainerHeight,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: smallContainerHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: smallContainerHeight,
            child: Center(child: Text('No file reading activity found.')),
          );
        }

        final logs = snapshot.data!;
        return Container(
          constraints: BoxConstraints(maxHeight: maxContainerHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.fileName,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.folderName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Page: ${log.lastPage}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
