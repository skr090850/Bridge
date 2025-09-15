import 'dart:math';

class StatusModel {
  final String projectName;
  final String company;
  final int statusPercent;

  StatusModel({
    required this.projectName,
    required this.company,
    required this.statusPercent,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      projectName: json['title'] ?? 'N/A',
      company: json['owner'] ?? 'Company, Designation',
      // Status ke liye random percentage generate kiya gaya hai (DEMO)
      statusPercent: Random().nextInt(85) + 5, // 5 se 90 ke beech
    );
  }
}
