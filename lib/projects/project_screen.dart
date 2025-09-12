import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchFolders() async {
    const String apiUrl = 'http://183.82.115.221/Bridge/BridgeApi/api/Template/GetprojFolders?tid=1&projid=4';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> decodedList = json.decode(response.body);
        return decodedList.cast<Map<String, dynamic>>().toList();
      } else {
        throw Exception('Failed to load folders. Status code: ${response.statusCode}');
      }
  } catch (e) {  
      print('An error occurred while fetching folders: $e');
      throw Exception('An error occurred while fetching data.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A Traffic Project'),
        backgroundColor: const Color(0xFF00A3D7),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFolders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No folders found.'));
          } else {
            final folders = snapshot.data!;
            return ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final title = folder['fname'] ?? 'Unnamed Folder';
                final subtitle = folder['fnamedesc'] ?? 'No description';

                return ListTile(
                  leading: const Icon(Icons.folder, color: Color(0xFF00A3D7), size: 40),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  onTap: () {
                    final folderId = folder['fid'];
                    final folderName = folder['fname'];
                    if (folderId != null && folderName != null) {
                       Navigator.pushNamed(
                        context, 
                        '/projectDetail',
                        arguments: {'id': folderId, 'name': folderName},
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Folder ID or Name is missing.'))
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

