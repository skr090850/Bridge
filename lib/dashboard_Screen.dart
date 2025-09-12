import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 40.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF00A3D7),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: const Text(
              'Welcome to the Bridge App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16.0),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              children: [
                _buildDashboardItem(
                  context,
                  icon: Icons.business_center,
                  label: 'PROJECTS',
                  onTap: () => Navigator.pushNamed(context, '/project'),
                ),
                _buildDashboardItem(
                  context,
                  icon: Icons.people,
                  label: 'MEMBERS',
                  onTap: () => Navigator.pushNamed(context, '/members'),
                ),
                _buildDashboardItem(
                  context,
                  icon: Icons.build,
                  label: 'SPARES',
                ),
                _buildDashboardItem(
                  context,
                  icon: Icons.folder,
                  label: 'RESOURCES',
                ),
                _buildDashboardItem(
                  context,
                  icon: Icons.bar_chart,
                  label: 'METRICS',
                ),
                _buildDashboardItem(
                  context,
                  icon: Icons.person_add,
                  label: 'REFER A CLIENT',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF00A3D7)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
