import 'package:flutter/foundation.dart';

class Project {
  final int projectId;
  final String title;
  final String coordinator;
  final String projectDesc; // Project ki description ke liye field add kiya hai

  Project({
    required this.projectId,
    required this.title,
    required this.coordinator,
    required this.projectDesc,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    debugPrint('Project JSON from API: $json');
    
    return Project(
      projectId: json['ProjectId'] ?? 0,
      title: json['title'] ?? 'No Project Name',
      coordinator: json['coordinator'] ?? 'N/A',
      // API se aa rahi project description ko yahaan parse kiya hai
      projectDesc: json['projectDesc'] ?? '<p>No description available.</p>',
    );
  }
}

