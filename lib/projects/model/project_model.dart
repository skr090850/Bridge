import 'package:flutter/foundation.dart';

class Project {
  final int projectId;
  final String title;
  final String projectDesc;
  
  // Coordinator ki poori details ke liye fields
  final String coordinatorName;
  final String coordinatorPosition;
  final String coordinatorDepartment;
  final String coordinatorOrganization;
  final String coordinatorEmail;
  final String coordinatorPhone;

  Project({
    required this.projectId,
    required this.title,
    required this.projectDesc,
    required this.coordinatorName,
    required this.coordinatorPosition,
    required this.coordinatorDepartment,
    required this.coordinatorOrganization,
    required this.coordinatorEmail,
    required this.coordinatorPhone,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final coordinatorInfo = json['CoordinatorUserInfo'] as Map<String, dynamic>?;
    final coordinatorDetails = json['CoordinatorUserDetails'] as Map<String, dynamic>?;

    return Project(
      projectId: json['ProjectId'] ?? 0,
      title: json['title'] ?? 'No Project Name',
      projectDesc: json['projectDesc'] ?? '<p>No description available.</p>',
      
      coordinatorName: json['coordinator'] ?? coordinatorInfo?['displayname'] ?? 'N/A',
      
      coordinatorPosition: coordinatorInfo?['position'] ?? 'N/A',
      coordinatorDepartment: coordinatorInfo?['dept'] ?? 'N/A',
      coordinatorOrganization: json['owner'] ?? coordinatorInfo?['organization'] ?? 'N/A',
      coordinatorEmail: coordinatorDetails?['email'] ?? 'N/A',
      coordinatorPhone: coordinatorInfo?['workphone'] ?? 'N/A',
    );
  }
}

