import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'status_model.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<StatusModel>> _activeStatusFuture;
  late Future<List<StatusModel>> _archiveStatusFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeStatusFuture = _fetchProjectStatus("active");
    _archiveStatusFuture = _fetchProjectStatus("archive");
  }

  Future<List<StatusModel>> _fetchProjectStatus(String statusType) async {
    const apiUrl =
        'http://183.82.115.221/Bridge/BridgeApi/api/Template/Myprojects';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': 1000, 'skip': 0, 'take': 20, 'srch': ''}),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> projectsJson;

        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('projects')) {
          projectsJson = responseData['projects'];
        } else if (responseData is List) {
          projectsJson = responseData;
        } else if (responseData is String) {
          final decodedString = json.decode(responseData);
          projectsJson = decodedString is List ? decodedString : [];
        } else {
          throw Exception('Unexpected JSON format from API');
        }

        if (statusType == "archive") {
          return [];
        }

        return projectsJson.map((json) => StatusModel.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load status. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching status: $e");
      throw Exception('Failed to load status');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Design ke anusaar custom TabBar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: primaryColor,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Archive'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Tab ka content
                  _buildStatusList(_activeStatusFuture),
                  // Archive Tab ka content
                  _buildStatusList(_archiveStatusFuture),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Status ki list dikhane wala reusable widget
  Widget _buildStatusList(Future<List<StatusModel>> future) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: primaryColor.withOpacity(0.1),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<StatusModel>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text("Error: Failed to load status.",
                        textAlign: TextAlign.center));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No projects found."));
              }

              final statuses = snapshot.data!;
              return ListView.separated(
                itemCount: statuses.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = statuses[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16.0),
                    title: Text(item.projectName,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(item.company,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 40, // Alignment ke liye
                            child: Text(
                              '${item.statusPercent}%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            )),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

