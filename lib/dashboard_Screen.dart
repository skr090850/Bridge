import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scrolling News ticker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

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

              // Dashboard Grid
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
                    onTap: () => Navigator.pushNamed(context, '/project'),
                  ),
                  _buildDashboardItem(
                    context,
                    imagePath: 'assets/images/members.jpg',
                    label: 'MEMBERS',
                    onTap: () => Navigator.pushNamed(context, '/members'),
                  ),
                  _buildDashboardItem(
                    context,
                    imagePath: 'assets/images/alert.jpg',
                    label: 'ALERTS',
                  ),
                  _buildDashboardItem(
                    context,
                    imagePath: 'assets/images/high_risk.jpg',
                    label: 'HI-RISK',
                  ),
                  _buildDashboardItem(
                    context,
                    imagePath: 'assets/images/status.jpg',
                    label: 'STATUS',
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[600],
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
            icon: Icon(Icons.sync_alt),
            label: 'Sync',
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

