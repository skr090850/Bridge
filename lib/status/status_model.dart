import 'dart:math';

class StatusModel {
  final int projectId;
  final String projectName;
  final String company;
  final int statusPercent;
  final bool isArchived;

  StatusModel({
    required this.projectId,
    required this.projectName,
    required this.company,
    required this.statusPercent,
    required this.isArchived,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json, {required bool isArchived}) {
    return StatusModel(
      projectId: json['ProjectId'] ?? 0,
      projectName: json['title'] ?? 'N/A',
      company: json['owner'] ?? 'Company, Designation',
      statusPercent: Random().nextInt(85) + 5,
      isArchived: isArchived,
    );
  }
}

