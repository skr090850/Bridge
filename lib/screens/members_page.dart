import 'package:flutter/material.dart';
import '../models/member.dart'; // Importing the Member model

// This is the Members page, now with a UI matching your design.
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  // Dummy data - Asal app mein yeh data API se aayega.
  final List<Member> members = const [
    Member(name: 'Customer 65', designation: 'Company Designation', company: 'Amrtech', smsCount: 3),
    Member(name: 'Customer 567', designation: 'Company Designation', company: 'Amrtech', smsCount: 5),
    Member(name: 'Amrtech', designation: 'Company Designation', company: 'Amrtech', smsCount: 8),
    Member(name: 'RRRR SSSS', designation: 'Company Designation', company: 'Amrtech', smsCount: 9),
    Member(name: 'Sri Senthil Croucher', designation: 'Company Designation', company: 'Amrtech', smsCount: 9),
    Member(name: 'Nadu KP', designation: 'Company Designation', company: 'Amrtech', smsCount: 7),
    Member(name: 'Durga Prasad', designation: 'Company Designation', company: 'Amrtech', smsCount: 1),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.person, color: Colors.orange),
            ),
            title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(member.designation),
            trailing: Text(
              member.smsCount.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            onTap: () {
              // Yahan user profile screen par navigate karenge
              print('Tapped on ${member.name}');
            },
          ),
        );
      },
    );
  }
}
