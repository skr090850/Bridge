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
  final int projectsCount;
  final List<UserProject> projects;

  final String department;
  final String workPhone;
  final String address;

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
    this.department = 'N/A',
    this.workPhone = 'N/A',
    this.address = 'N/A',
  });

  factory Member.fromJson(Map<String, dynamic> json) {
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
    );
  }

  factory Member.fromDetailJson(Map<String, dynamic> json) {
    var projectsList = <UserProject>[];
    if (json['ProjectsList'] != null) {
      projectsList = (json['ProjectsList'] as List)
          .map((p) => UserProject.fromJson(p))
          .toList();
    }
    
    final String fullAddress = [
      json['doorno'],
      json['locality'],
      json['street'],
      json['city'],
      json['state'],
      json['country'],
      json['zipcode']
    ].where((s) => s != null && s.isNotEmpty).join(', ');


    return Member(
      id: json['id'] ?? 0,
      displayname: json['displayname'] ?? json['loginname'] ?? 'N/A',
      loginname: json['loginname'] ?? 'N/A',
      organization: json['organization'] ?? 'N/A',
      position: json['position'] ?? 'No designation',
      role: json['role'] ?? 'user',
      email: json['email'] ?? 'N/A',
      photo1: json['photo1'] ?? '',
      projectsCount: json['Projects'] ?? 0,
      projects: projectsList,
      department: json['dept'] ?? 'N/A',
      workPhone: json['workphone'] ?? 'N/A',
      address: fullAddress.isNotEmpty ? fullAddress : 'N/A',
    );
  }
}

