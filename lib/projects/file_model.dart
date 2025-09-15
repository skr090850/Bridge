import 'dart:math';
import 'package:intl/intl.dart';

class FileModel {
  final int id;
  final String name;
  final String type;
  final String size;
  final String dateModified;

  FileModel({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.dateModified,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    // Helper function to format file size from bytes to KB, MB, etc.
    String formatBytes(int bytes, int decimals) {
      if (bytes <= 0) return "0 B";
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (log(bytes) / log(1024)).floor();
      return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
    }

    // Helper function to get file type from filename extension
    String getFileType(String filename) {
      if (filename.contains('.')) {
        return ".${filename.split('.').last.toUpperCase()}";
      }
      return 'File';
    }

    // Helper function to format date string
    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return 'N/A';
      try {
        // Attempt to parse the date
        final date = DateTime.parse(dateStr);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        // If parsing fails, return the original string or a default value
        return 'N/A';
      }
    }

    return FileModel(
      // Using the correct keys from the API response
      id: json['pffid'] ?? 0,
      name: json['filename'] ?? 'Unnamed File',
      type: getFileType(json['filename'] ?? ''),
      size: formatBytes(json['filesize'] ?? 0, 2),
      dateModified: formatDate(json['createddate']),
    );
  }
}

