import 'package:flutter/foundation.dart';
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
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    _userId = arguments?['userId'] ?? 1000;
    _membersFuture = _fetchMembers(_userId!);
  }

  Future<List<Member>> _fetchMembers(int userId) async {
    final url = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetMemberList/?memtype=company&id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Member.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load members. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
      throw Exception('Failed to fetch members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Member',
                  // style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  style:textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Projects',
                  // style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  style:textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
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
                  final members = snapshot.data!;
                  return ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      const String photoBaseUrl =
                          'http://183.82.115.221/Bridge/BridgeApi/img/users/';
                      final String photoUrl = photoBaseUrl + member.photo1;

                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemberDetailScreen(
                                  userId: _userId!,
                                  memberId: member.id,
                                  memberName: member.displayname),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: member.photo1.isEmpty
                              ? Icon(Icons.person_outline,
                                  color: Colors.grey[600])
                              : ClipOval(
                                  child: Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Icon(Icons.person_outline,
                                          color: Colors.grey[600]);
                                    },
                                  ),
                                ),
                        ),
                        title: Text(member.displayname,
                            // style:
                            //     const TextStyle(fontWeight: FontWeight.w500)
                            style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${member.organization}, ${member.position}',
                          // style: TextStyle(
                          //     fontSize: 12, color: Colors.grey[600]),
                          style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          member.projectsCount.toString(),
                          // style: const TextStyle(
                          //     fontWeight: FontWeight.bold, fontSize: 16),
                          style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold),
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

