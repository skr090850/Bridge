import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'image_upload_service.dart';
import 'member_model.dart';
import 'user_project_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Future<List<UserProject>> _projectsFuture;
  final ImageUploadService _uploadService = ImageUploadService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchUserProjects(widget.member.id);
  }

  Future<List<UserProject>> _fetchUserProjects(int userId) async {
    final response = await http.post(
      Uri.parse(
          'http://183.82.115.221/Bridge/BridgeApi/api/Template/myprocjectuser'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'uid': userId, 'skip': 0, 'take': 10, 'srch': ''}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('projects')) {
        final List<dynamic> projectsJson = responseData['projects'];
        return projectsJson.map((json) => UserProject.fromJson(json)).toList();
      } else {
        throw Exception('Unexpected JSON format from projects API');
      }
    } else {
      throw Exception('Failed to load user projects');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isUploading = true;
      });

      final success = await _uploadService.uploadImage(
        imageFile: File(image.path),
        projectId: '4',
        folderId: '1',
        userId: widget.member.id.toString(),
      );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Image uploaded successfully!' : 'Image upload failed.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String subject, String message) async {
    // NOTE: MailFromId would typically be the logged-in user's ID.
    // Hardcoding '1000' as a placeholder based on the API example.
    const mailFromId = 1000;
    final mailToId = widget.member.id.toString();
    final formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final emailData = {
      "MailFromId": mailFromId,
      "fid": 1,
      "projectid": 4,
      "MailSub": subject,
      "MailToids": mailToId,
      "MailMessage": message,
      "MailPerson": null,
      "createddate": formattedDate,
      "processdate": formattedDate,
      "Type": "Folders",
      "MailEventId": 0,
      "processid": null,
      "status": 0
    };

    try {
      final response = await http.post(
        Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/template/AddMailalerts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(emailData),
      );

      if (mounted) {
        // Check for both status code 200 and if the response body is "true"
        if (response.statusCode == 200 && response.body.toLowerCase() == 'true') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Email sent successfully!'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to send email. Server responded with: ${response.body}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('An error occurred: $e'),
                backgroundColor: Colors.red),
          );
      }
    }
  }

  void _showSendEmailDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (value) => value!.isEmpty ? 'Subject cannot be empty' : null,
                ),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                   validator: (value) => value!.isEmpty ? 'Message cannot be empty' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if(formKey.currentState!.validate()){
                   _sendEmail(subjectController.text, messageController.text);
                   Navigator.of(context).pop();
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) {
      return 'N/A';
    }
    // Handles both yyyy-MM-dd and dd-MM-yyyy formats by replacing hyphens
    final DateTime? date = DateTime.tryParse(dateString.replaceAll('-', '/'));
    if (date != null) {
      return DateFormat('dd/MM/yy').format(date);
    } else {
      // Fallback for other potential formats, though might not be perfect
      try {
        return DateFormat('dd/MM/yy').format(DateFormat("dd-MM-yyyy").parse(dateString));
      } catch (e) {
        return 'N/A';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String photoBaseUrl =
        'http://183.82.115.221/Bridge/BridgeApi/img/users/';
    final String photoUrl = photoBaseUrl + widget.member.photo1;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.loginname),
      ),
      body: FutureBuilder<List<UserProject>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          int projectCount = 0;
          if (snapshot.hasData) {
            projectCount = snapshot.data!.length;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            child: widget.member.photo1.isEmpty
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.grey)
                                : ClipOval(
                                    child: Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(Icons.person,
                                            size: 50, color: Colors.grey);
                                      },
                                    ),
                                  ),
                          ),
                          Column(
                            children: [
                              Text(
                                projectCount.toString(),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const Text('PROJECTS'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.member.loginname,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.member.organization,
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.member.email,
                        style: TextStyle(fontSize: 16, color: primaryColor),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                _isUploading ? null : _pickAndUploadImage,
                            icon: _isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt),
                            label: Text(_isUploading
                                ? 'Uploading...'
                                : 'Upload New Photo'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12)),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showSendEmailDialog,
                            icon: const Icon(Icons.email),
                            label: const Text('Send Email'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Projects Table
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildProjectTableHeader(primaryColor),
                      _buildProjectTableBody(snapshot, primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectTableHeader(Color headerColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
          color: headerColor.withOpacity(0.1),
          border: Border(bottom: BorderSide(color: headerColor, width: 2))),
      child: const Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 4,
              child: Text('Project Name',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 3,
              child: Text('Role',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildProjectTableBody(
      AsyncSnapshot<List<UserProject>> snapshot, Color primaryColor) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ));
    } else if (snapshot.hasError) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          'Failed to load projects: ${snapshot.error}',
          textAlign: TextAlign.center,
        ),
      ));
    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text('No projects found for this member.'),
        ),
      );
    } else {
      final projects = snapshot.data!;
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
            child: Row(
              children: [
                Expanded(
                    flex: 2, child: Text(_formatDate(project.createdDate))),
                Expanded(
                    flex: 4,
                    child: Text(
                      project.projectName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                Expanded(
                    flex: 3,
                    child: Text(
                      project.role,
                      textAlign: TextAlign.right,
                    )),
              ],
            ),
          );
        },
      );
    }
  }
}

