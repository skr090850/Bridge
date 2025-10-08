class UserProject {
  final int projectId;
  final String projectName;

  UserProject({required this.projectId, required this.projectName});

  factory UserProject.fromJson(Map<String, dynamic> json) {
    return UserProject(
      projectId: json['projid'] ?? 0,
      projectName: json['projname'] ?? 'No Project Name',
    );
  }
}