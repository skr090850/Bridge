import 'dart:io';
import 'package:bridge/Server/server_url.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageUploadService {
  static String _baseUrl = '${baseUrl}Bridge/PostUserImage';

  Future<bool> uploadImage({
    required File imageFile,
    required String projectId,
    required String folderId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl);
      final request = http.MultipartRequest('POST', uri);

      // Text fields add karein
      request.fields['projid'] = projectId;
      request.fields['fid'] = folderId;
      request.fields['uid'] = userId;

      // File add karein
      request.files.add(
        await http.MultipartFile.fromPath(
          'file_1', // API ke hisaab se key name
          imageFile.path,
        ),
      );

      debugPrint('Uploading image for user: $userId');
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        debugPrint('Upload successful: $responseBody');
        return true;
      } else {
        final responseBody = await response.stream.bytesToString();
        debugPrint('Upload failed with status ${response.statusCode}: $responseBody');
        return false;
      }
    } catch (e) {
      debugPrint('An error occurred during image upload: $e');
      return false;
    }
  }
}
