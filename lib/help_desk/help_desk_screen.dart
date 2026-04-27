import 'package:bridge/Server/server_url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../projects/model/project_model.dart';
import 'new_ticket_screen.dart';

class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Project> _searchResults = [];
  bool _isLoading = false;
  String _message = 'Search for a project to begin.';

  Future<void> _searchProjects(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _message = 'Please enter a project name to search.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _message = ''; 
    });

    String apiUrl =
        '${baseUrl}Template/Myprojects';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': 1000, 'skip': 0, 'take': 20, 'srch': query}),
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
          if (decodedString is List) {
            projectsJson = decodedString;
          } else {
            throw Exception('Unexpected format inside string response');
          }
        } else {
          throw Exception('Unexpected JSON format from API');
        }

        setState(() {
          _searchResults =
              projectsJson.map((json) => Project.fromJson(json)).toList();
          if (_searchResults.isEmpty) {
            _message = 'No projects found matching your search.';
          }
        });
      } else {
        setState(() {
          _message = 'Error searching projects. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Project'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Project',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchProjects(_searchController.text),
                ),
              ),
              onSubmitted: _searchProjects,
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final project = _searchResults[index];
                  return ListTile(
                    title: Text(project.title),
                    subtitle:
                        Text('Customer ID: ${project.projectId}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NewTicketScreen(project: project),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                  child: Text(
                _message,
                textAlign: TextAlign.center,
              )),
            ),
        ],
      ),
    );
  }
}

