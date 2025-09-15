import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'projects/project_screen.dart';
import 'projects/project_detail_screen.dart';
import 'members/members_screen.dart';
import 'members/member_detail_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the primary orange color for the theme
    const Color primaryOrange = Color(0xFFF27121);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bridge App',
      // Apply the new, robust orange theme globally using ColorScheme
      theme: ThemeData(
        // Use ColorScheme.fromSeed and explicitly set the primary color
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          // This ensures your exact orange is used as the primary color
          primary: primaryOrange,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        
        // Define styles for the app bar
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

        // Define styles for elevated buttons
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

        // Define styles for text buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryOrange,
          ),
        ),
        
        // Define styles for input fields
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
      // Your existing routes
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/project': (context) => const ProjectScreen(),
        // '/projectDetail': (context) => ProjectDetailScreen(),
        '/members': (context) => const MembersScreen(),
      },
    );
  }
}

