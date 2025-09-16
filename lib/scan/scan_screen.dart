import 'package:flutter/material.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Scanner Screen',
              style: TextStyle(fontSize: 24, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
