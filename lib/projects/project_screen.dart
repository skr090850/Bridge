import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'project_model.dart';
import 'project_detail_screen.dart'; // This screen will show folders for a project

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late Future<List<Project>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects(1000); 
  }

  Future<List<Project>> _fetchProjects(int userId) async {
    const String apiUrl = 'http://183.82.115.221/Bridge/BridgeApi/api/Template/myprocjectuser';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': userId, 'skip': 0, 'take': 20, 'srch': ''}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic> && responseData.containsKey('projects')) {
          final List<dynamic> projectsJson = responseData['projects'];
          return projectsJson.map((json) => Project.fromJson(json)).toList();
        } else {
           throw Exception('Unexpected JSON format from projects API');
        }
      } else {
        throw Exception('Failed to load projects. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('An error occurred while fetching projects: $e');
      throw Exception('An error occurred while fetching data.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            width: double.infinity,
            color: primaryColor,
            child: const Text(
              'PROJECTNAME',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Project>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No projects found.'));
                } else {
                  final projects = snapshot.data!;
                  return ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.settings_input_component_outlined,
                              color: primaryColor,
                              size: 32,
                            ),
                            title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(project.coordinator),
                            onTap: () {
                              // Navigation ko theek kiya gaya hai
                              // Ab poora project object detail screen par bheja ja raha hai
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailScreen(
                                    project: project,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

