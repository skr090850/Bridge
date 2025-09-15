import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import 'member_model.dart';
import 'user_project_model.dart';
import '../projects/project_detail_screen.dart'; // ProjectDetailScreen ko import kiya gaya hai

class MemberDetailScreen extends StatefulWidget {
  final int memberId;
  final String memberName;

  const MemberDetailScreen(
      {super.key, required this.memberId, required this.memberName});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Future<Member> _memberDetailsFuture;

  @override
  void initState() {
    super.initState();
    _memberDetailsFuture = _fetchMemberDetails(widget.memberId);
  }

  Future<Member> _fetchMemberDetails(int memberId) async {
    final response = await http.get(Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/bridge/ViewMember?id=$memberId'));

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData is String) {
        final Map<String, dynamic> data = json.decode(responseData);
        return Member.fromDetailJson(data);
      } else if (responseData is Map<String, dynamic>) {
        return Member.fromDetailJson(responseData);
      } else {
        throw Exception('Unexpected JSON format from ViewMember API');
      }
    } else {
      throw Exception('Failed to load member details');
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty || dateString == "N/A") {
      return 'N/A';
    }
    try {
      DateFormat format = DateFormat("dd/MM/yyyy");
      if (dateString.contains("-")) {
        format = DateFormat("dd-MM-yyyy");
      }
      final DateTime date = format.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    const String photoBaseUrl =
        'http://183.82.115.221/Bridge/BridgeApi/img/users/';
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memberName),
      ),
      body: FutureBuilder<Member>(
        future: _memberDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading details: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Member not found.'));
          }

          final member = snapshot.data!;
          final String photoUrl = photoBaseUrl + member.photo1;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            child: member.photo1.isEmpty
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
                                member.projects.length.toString(),
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
                        member.displayname.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        member.position,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member.email,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildProjectTableHeader(primaryColor),
                      _buildProjectTableBody(member.projects, primaryColor),
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
      ),
      child: const Row(
        children: [
          Expanded(
              flex: 2,
              child:
                  Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
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
      List<UserProject> projects, Color primaryColor) {
    if (projects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text('No projects found for this member.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return InkWell( // Project row ko tappable banaya gaya hai
          onTap: () {
            // ProjectDetailScreen par navigate karne ka logic
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetailScreen(
                  projectId: project.projectId,
                  projectTitle: project.projectName,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.grey[200]!))),
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
          ),
        );
      },
    );
  }
}

