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

  // JSON se data parse karne ke liye factory constructor
  factory Folder.fromJson(Map<String, dynamic> json) {
    // Is debug print se hum confirm kar sakte hain ki yeh naya code chal raha hai
    debugPrint("Parsing folder: ${json['fname']}");

    return Folder(
      // API se aa rahe 'fid' ko id ke liye istemal kiya hai
      id: json['fid'] ?? 0,
      // API se aa rahe 'fname' ko name ke liye istemal kiya hai
      name: json['fname'] ?? 'Unnamed Folder',
      // API se aa rahe 'fnamedesc' ko description ke liye istemal kiya hai
      description: json['fnamedesc'] ?? 'No description',
    );
  }
}

