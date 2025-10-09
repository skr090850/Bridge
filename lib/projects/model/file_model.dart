import 'dart:math';
import 'package:intl/intl.dart';

class FileModel {
  final int id;
  final int folderId;
  final String name;
  final String type;
  final String size;
  final String dateModified;

  FileModel({
    required this.id,
    required this.folderId,
    required this.name,
    required this.type,
    required this.size,
    required this.dateModified,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    String formatBytes(int bytes, int decimals) {
      if (bytes <= 0) return "0 B";
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (log(bytes) / log(1024)).floor();
      return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
    }

    String getFileType(String filename) {
      if (filename.contains('.')) {
        return ".${filename.split('.').last.toUpperCase()}";
      }
      return 'File';
    }

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return 'N/A';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        return 'N/A';
      }
    }

    return FileModel(
      id: json['pffid'] ?? 0,
      folderId: json['fid'] ?? 0,
      name: json['filename'] ?? 'Unnamed File',
      type: getFileType(json['filename'] ?? ''),
      size: formatBytes(json['filesize'] ?? 0, 2),
      dateModified: formatDate(json['createddate']),
    );
  }
}

