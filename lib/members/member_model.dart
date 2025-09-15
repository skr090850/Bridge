import 'user_project_model.dart';

class Member {
  final int id;
  final String displayname;
  final String loginname;
  final String organization;
  final String position;
  final String role;
  final String email;
  final String photo1;
  final int projectsCount; // Projects ki ginti ke liye naya field
  final List<UserProject> projects;

  Member({
    required this.id,
    required this.displayname,
    required this.loginname,
    required this.organization,
    required this.position,
    required this.role,
    required this.email,
    required this.photo1,
    required this.projectsCount,
    this.projects = const [],
  });

  // GetMemberList API (list view) ke liye
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      displayname: json['displayname'] ?? 'N/A',
      loginname: json['loginname'] ?? 'N/A',
      organization: json['organization'] ?? 'N/A',
      position: json['position'] ?? 'No designation',
      role: json['role'] ?? 'user', // Default role
      email: json['email'] ?? 'N/A',
      photo1: json['photo1'] ?? '',
      projectsCount: json['Projects'] ?? 0, // API se 'Projects' count parse kiya gaya hai
    );
  }

  // ViewMember API (detail view) ke liye
  factory Member.fromDetailJson(Map<String, dynamic> json) {
    var projectsList = <UserProject>[];
    if (json['ProjectsList'] != null) {
      projectsList = (json['ProjectsList'] as List)
          .map((p) => UserProject.fromJson(p))
          .toList();
    }

    return Member(
      id: json['id'] ?? 0,
      displayname: json['displayname'] ?? 'N/A',
      loginname: json['loginname'] ?? 'N/A',
      organization: json['organization'] ?? 'N/A',
      position: json['position'] ?? 'No designation',
      role: json['role'] ?? 'user',
      email: json['email'] ?? 'N/A',
      photo1: json['photo1'] ?? '',
      projectsCount: json['Projects'] ?? 0,
      projects: projectsList,
    );
  }
}

