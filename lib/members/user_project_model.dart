import 'package:flutter/foundation.dart';

class UserProject {
  final String projectName;
  final String role;
  final String createdDate;

  UserProject({
    required this.projectName,
    required this.role,
    required this.createdDate,
  });

  factory UserProject.fromJson(Map<String, dynamic> json) {
    debugPrint('Project JSON from API: $json');

    String dateValue = json['updatedby'] ?? '';
    if (dateValue.contains('|')) {
      dateValue = dateValue.split('|')[0].trim();
    }

    return UserProject(
      projectName: json['title'] ?? 'No Project Name',
      role: 'Not Specified', 
      
      createdDate: dateValue,
    );
  }
}

