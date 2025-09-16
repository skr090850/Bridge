import 'package:flutter/material.dart';
import 'dart:async';
import 'help_desk/help_desk_screen.dart';
import 'alerts/alert_screen.dart';
import 'scan/scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) _startScrolling();
    });
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 10),
          curve: Curves.linear,
        ).then((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildDashboardGrid(Map<String, dynamic>? arguments) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: const Text(
                        'Welcome to the Bridge App... Your one-stop solution for project management...',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Bridge',
                  style: TextStyle(
                    fontSize: 48,
                    fontFamily: 'serif',
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/setting.jpg',
                  label: 'PROJECTS',
                  onTap: () => Navigator.pushNamed(context, '/project',
                      arguments: arguments),
                ),
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/members.jpg',
                  label: 'MEMBERS',
                  onTap: () => Navigator.pushNamed(context, '/members',
                      arguments: arguments),
                ),
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/alert.jpg',
                  label: 'ALERTS',
                  onTap: () => Navigator.pushNamed(context, '/alerts',
                      arguments: arguments),
                ),
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/high_risk.jpg',
                  label: 'HELPDESK',
                  onTap: () => Navigator.pushNamed(context, '/helpdesk',
                      arguments: arguments),
                ),
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/status.jpg',
                  label: 'STATUS',
                  onTap: () => Navigator.pushNamed(context, '/status',
                      arguments: arguments),
                ),
                _buildDashboardItem(
                  context,
                  imagePath: 'assets/images/metrics.jpg',
                  label: 'METRICS',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
    final List<Widget> _screens = [
      _buildDashboardGrid(arguments),
      const HelpdeskScreen(),       
      const ScanScreen(),         
      const AlertsScreen(), 
    ];
    
    final List<String> _screenTitles = [
      'Dashboard',
      'Issues',
      'Scan',
      'Alerts',
    ];

    return Scaffold(
      appBar: _selectedIndex ==0 ?  AppBar(
        title: Text(_screenTitles[_selectedIndex]),
      ):null,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(
    BuildContext context, {
    required String imagePath,
    required String label,
    VoidCallback? onTap,
  }) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              height: 40,
              width: 40,
              // color: primaryColor,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.error_outline, color: Colors.red, size: 40);
              },
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

