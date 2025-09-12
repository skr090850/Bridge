import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://183.82.115.221/Bridge/BridgeApi/api';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // Login User
  static Future<Map<String, dynamic>> login(String uid, String pwd) async {
    final Uri url = Uri.parse('$_baseUrl/Bridge/getLogin');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(<String, String>{
          'uid': uid,
          'pwd': pwd,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to login. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  //  Get User's Projects
  static Future<List<dynamic>> getMyProjects(int uid, {int skip = 0, int take = 10, String srch = ""}) async {
    final Uri url = Uri.parse('$_baseUrl/Template/myprocjectuser');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'uid': uid,
          'skip': skip,
          'take': take,
          'srch': srch,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load projects. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get Project Folders
  static Future<List<dynamic>> getProjectFolders({required int tid, required int projid}) async {
    final Uri url = Uri.parse('$_baseUrl/Template/GetprojFolders?tid=$tid&projid=$projid');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load folders. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get Folder Files
  static Future<List<dynamic>> getFolderFiles(int projid) async {
    final Uri url = Uri.parse('$_baseUrl/Bridge/files?_projid=$projid');
     try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load files. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
  
  // Get PDF Data
  static Future<http.Response> getFileData(int fileId) async {
    final Uri url = Uri.parse('$_baseUrl/Bridge/GetpdfData?id=$fileId');
    try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
            return response;
        } else {
            throw Exception('Failed to get file data. Status code: ${response.statusCode}');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<List<dynamic>> getMailRecipients(int projectid) async {
    final Uri url = Uri.parse('$_baseUrl/template/getmemberAssainersList?id=$projectid');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get mail recipients. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<bool> sendEmailAlert({required Map<String, dynamic> mailData}) async {
    final Uri url = Uri.parse('$_baseUrl/template/AddMailalerts');
    try {
        final response = await http.post(
            url,
            headers: _headers,
            body: jsonEncode(mailData),
        );
        if (response.statusCode == 200) {
            return true;
        } else {
            throw Exception('Failed to send email. Status code: ${response.statusCode}');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server: $e');
    }
  }
}
