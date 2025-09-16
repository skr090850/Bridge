import 'package:bridge/alerts/alert_screen.dart';
import 'package:bridge/status/status_screen.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'projects/project_screen.dart';
import 'projects/project_detail_screen.dart';
import 'members/members_screen.dart';
import 'members/member_detail_screen.dart';
import 'help_desk/help_desk_screen.dart';
// import 'home_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFF27121);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bridge App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          primary: primaryOrange,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryOrange,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white)
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryOrange,
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryOrange, width: 2),
          ),
          prefixIconColor: Colors.grey[500],
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        // '/home': (context) => const HomeScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/project': (context) => const ProjectScreen(),
        // '/projectDetail': (context) => ProjectDetailScreen(),
        '/members': (context) => const MembersScreen(),
        '/alerts':(context) => const AlertsScreen(),
        '/helpdesk':(context) => const HelpdeskScreen(),
        '/status':(context) => const StatusScreen(),
      },
    );
  }
}

