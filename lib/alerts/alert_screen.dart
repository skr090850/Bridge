import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_screen.dart';
import 'alert_model.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<Alert>> _alertsFuture;
  int _currentUserId = 1000; // Default/fallback user ID

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _currentUserId = arguments?['userId'] ?? 1000;
    _alertsFuture = _fetchAlerts(_currentUserId);
  }

  Future<List<Alert>> _fetchAlerts(int userId) async {
    final url = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetMemberList/?memtype=company&id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Alert.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load alerts. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
      throw Exception('Failed to fetch alerts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
      ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: primaryColor.withOpacity(0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Projects',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('SMS',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Alert>>(
              future: _alertsFuture,
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
                  return const Center(child: Text('No alerts found.'));
                } else {
                  final alerts = snapshot.data!;
                  return ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return ListTile(
                        leading:
                            Icon(Icons.person_outline, color: Colors.grey[600]),
                        title: Text(alert.name,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(alert.designation,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        trailing: Text(alert.smsCount.toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        onTap: () {
                          // Chat screen par navigate karein, ab ID bhi pass ho raha hai
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatScreen(
                                    currentUserId: _currentUserId,
                                    chatPartnerId: alert.id,
                                    chatPartnerName: alert.name,
                                  ),
                            ),
                          );
                        },
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

