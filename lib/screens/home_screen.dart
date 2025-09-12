import 'package:flutter/material.dart';
import 'projects_page.dart';
import 'members_page.dart';   
import 'alerts_page.dart';    

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tracks the currently selected tab

  // A list of the pages to be displayed for each tab.
  static const List<Widget> _widgetOptions = <Widget>[
    ProjectsPage(), // Index 0
    MembersPage(),  // Index 1
    AlertsPage(),   // Index 2
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // An array of titles for the AppBar
    const List<String> _appBarTitles = ['Projects', 'Members', 'Alerts'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // Title changes with tab
        centerTitle: true,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
