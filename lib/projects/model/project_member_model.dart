class ProjectMember {
  final int id;
  final String name;
  bool isSelected;

  ProjectMember({required this.id, required this.name, this.isSelected = false});

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'] ?? 0,
      name: json['loginname'] ?? 'Unknown User',
    );
  }
}
