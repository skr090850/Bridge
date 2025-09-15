import 'package:flutter/foundation.dart';

class UserProject {
  final int projectId; // Project ID ke liye naya field
  final String projectName;
  final String role;
  final String createdDate;

  UserProject({
    required this.projectId,
    required this.projectName,
    required this.role,
    required this.createdDate,
  });

  factory UserProject.fromJson(Map<String, dynamic> json) {
    debugPrint('Parsing Project for Member: $json');

    String date = 'N/A';
    if (json['updatedBy'] != null && json['updatedBy'].toString().isNotEmpty) {
      date = json['updatedBy'].toString().split('|').first.trim();
    }

    return UserProject(
      projectId: json['ProjectId'] ?? 0, // API se ProjectId parse kiya gaya hai
      projectName: json['projectname'] ?? 'No Project Name',
      role: json['Role'] ?? 'Not Specified',
      createdDate: date,
    );
  }
}

