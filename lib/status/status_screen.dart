import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'status_model.dart';
import '../projects/project_detail_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late Future<List<StatusModel>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _fetchAllStatus();
  }

  Future<List<StatusModel>> _fetchAllStatus() async {
    try {
      final results = await Future.wait([
        _fetchProjectStatus(isArchived: false),
        _fetchProjectStatus(isArchived: true),
      ]);
      return [...results[0], ...results[1]];
    } catch (e) {
      debugPrint("Error fetching all statuses: $e");
      throw Exception('Failed to load statuses');
    }
  }

  Future<List<StatusModel>> _fetchProjectStatus({required bool isArchived}) async {
    const apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/Myprojects';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': 1000, 'skip': 0, 'take': 20, 'srch': ''}),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> projectsJson;

        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('projects')) {
          projectsJson = responseData['projects'];
        } else if (responseData is List) {
          projectsJson = responseData;
        } else if (responseData is String) {
          final decodedString = json.decode(responseData);
          projectsJson = decodedString is List ? decodedString : [];
        } else {
          throw Exception('Unexpected JSON format from API');
        }

        if (isArchived) {
           return projectsJson.skip(3).map((json) => StatusModel.fromJson(json, isArchived: true)).toList();
        } else {
           return projectsJson.take(3).map((json) => StatusModel.fromJson(json, isArchived: false)).toList();
        }

      } else {
        throw Exception(
            'Failed to load status. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching status: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
      ),
      body: Column(
        children: [
          _buildLegendHeader(),
          _buildListHeader(),
          Expanded(
            child: FutureBuilder<List<StatusModel>>(
              future: _statusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error: ${snapshot.error}",
                          textAlign: TextAlign.center));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No projects found."));
                }

                final allProjects = snapshot.data!;

                return ListView.separated(
                  itemCount: allProjects.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = allProjects[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      title: Text(item.projectName,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(item.company,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12, 
                            height: 12, 
                            color: item.isArchived ? Colors.grey : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${item.statusPercent}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProjectDetailScreen(
                              projectId: item.projectId,
                              projectTitle: item.projectName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(width: 10, height: 10, color: Colors.red),
          const SizedBox(width: 4),
          const Text('Active', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Container(width: 10, height: 10, color: Colors.grey),
          const SizedBox(width: 4),
          const Text('Archive', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: primaryColor.withOpacity(0.1),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

