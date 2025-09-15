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

  // Is factory constructor ko update kiya gaya hai taaki yeh dono tarah ke API response handle kar sake
  factory Project.fromJson(Map<String, dynamic> json) {
    // Nested JSON objects se data nikaalne ke liye null checks
    final coordinatorInfo = json['CoordinatorUserInfo'] as Map<String, dynamic>?;
    final coordinatorDetails = json['CoordinatorUserDetails'] as Map<String, dynamic>?;

    return Project(
      projectId: json['ProjectId'] ?? 0,
      title: json['title'] ?? 'No Project Name',
      projectDesc: json['projectDesc'] ?? '<p>No description available.</p>',
      
      // LOGIC UPDATE: Ab yeh pehle simple 'coordinator' key check karta hai,
      // aur agar woh na mile, tab complex object 'CoordinatorUserInfo' check karta hai.
      coordinatorName: json['coordinator'] ?? coordinatorInfo?['displayname'] ?? 'N/A',
      
      // Baaki ke fields detail API ke liye hain, isliye list mein N/A aayega
      coordinatorPosition: coordinatorInfo?['position'] ?? 'N/A',
      coordinatorDepartment: coordinatorInfo?['dept'] ?? 'N/A',
      coordinatorOrganization: json['owner'] ?? coordinatorInfo?['organization'] ?? 'N/A', // owner ko fallback banaya gaya hai
      coordinatorEmail: coordinatorDetails?['email'] ?? 'N/A',
      coordinatorPhone: coordinatorInfo?['workphone'] ?? 'N/A',
    );
  }
}

