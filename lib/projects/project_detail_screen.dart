import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_html/flutter_html.dart';
import 'project_model.dart';
import 'folder_model.dart';
import 'file_list_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<List<Folder>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _foldersFuture = _fetchFolders(widget.project.projectId);
  }

  Future<List<Folder>> _fetchFolders(int projectId) async {
    final String apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/GetprojFolders?tid=1&projid=$projectId';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);
        List<dynamic> data;
        if (decodedBody is String) {
          data = json.decode(decodedBody);
        } else if (decodedBody is List) {
          data = decodedBody;
        } else {
          throw Exception('Unexpected response format for folders');
        }
        
        // Yeh line raw data ko console mein print karegi
        debugPrint('RAW FOLDER DATA FROM API: $data');

        return data.map((json) => Folder.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load folders. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('An error occurred while fetching folders: $e');
      throw Exception('An error occurred while fetching folder data.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Html(data: widget.project.projectDesc),
            const Divider(height: 32, thickness: 1),
            FutureBuilder<List<Folder>>(
              future: _foldersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No folders found in this project.'));
                } else {
                  final folders = snapshot.data!;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          // File list screen par navigate karne ka logic
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FileListScreen(
                                projectId: widget.project.projectId,
                                folderId: folder.id,
                                folderName: folder.name,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_outlined,
                                color: primaryColor, size: 50),
                            const SizedBox(height: 8),
                            Text(
                              folder.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

