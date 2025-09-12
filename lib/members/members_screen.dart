import 'package:flutter/foundation.dart'; // debugPrint ke liye import karein
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'member_model.dart';
import 'member_detail_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late Future<List<Member>> _membersFuture;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _membersFuture = _fetchMembers();
    _searchController.addListener(_filterMembers);
  }

  Future<List<Member>> _fetchMembers() async {
    const projectId = 4;
    final url = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/template/getmemberAssainersList?id=$projectId');

    try {
      final response = await http.get(url);

      // VS Code Debug Console mein response dekhne ke liye debugPrint ka istemal
      debugPrint('RAW RESPONSE FROM SERVER: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);

        List<dynamic> data;
        if (decodedBody is String) {
          // Agar response body ek string hai jiske andar JSON hai
          data = json.decode(decodedBody);
        } else if (decodedBody is List) {
          // Agar response body seedhe ek JSON list hai
          data = decodedBody;
        } else {
          throw Exception('Unexpected response format');
        }

        List<Member> members =
            data.map((json) => Member.fromJson(json)).toList();
        setState(() {
          _allMembers = members;
          _filteredMembers = members;
        });
        return members;
      } else {
        throw Exception(
            'Failed to load members. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Error ko console mein print karein
      debugPrint('Error fetching members: $e');
      throw Exception('Failed to fetch members: $e');
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers = _allMembers.where((member) {
        final nameLower = member.loginname.toLowerCase();
        final emailLower = member.email.toLowerCase();
        final orgLower = member.organization.toLowerCase();
        return nameLower.contains(query) ||
            emailLower.contains(query) ||
            orgLower.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Members',
                hintText: 'Search by name, email, or organization...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Member>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center),
                  ));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No members found.'));
                } else {
                  return ListView.builder(
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      const String photoBaseUrl =
                          'http://183.82.115.221/Bridge/BridgeApi/img/users/';
                      final String photoUrl = photoBaseUrl + member.photo1;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MemberDetailScreen(member: member),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            // Image load error ko handle karne ke liye child ka istemal karein
                            child: member.photo1.isEmpty
                                ? const Icon(Icons.person, color: Colors.grey)
                                : ClipOval(
                                    child: Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      // Image load hote samay loading indicator dikhayein
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
                                      },
                                      // Error hone par placeholder icon dikhayein
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.person, color: Colors.grey);
                                      },
                                    ),
                                  ),
                          ),
                          title: Text(member.loginname,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.email),
                              const SizedBox(height: 2),
                              Text(member.organization,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(member.role,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12)),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

