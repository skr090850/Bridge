import 'package:flutter/foundation.dart';

class Folder {
  final int id;
  final String name;
  final String description;

  Folder({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    debugPrint("Parsing folder: ${json['fname']}");

    return Folder(
      id: json['fid'] ?? 0,
      name: json['fname'] ?? 'Unnamed Folder',
      description: json['fnamedesc'] ?? 'No description',
    );
  }
}

