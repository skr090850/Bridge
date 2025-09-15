class Alert {
  final int id;
  final String name;
  final String designation;
  final int smsCount;

  Alert({
    required this.id,
    required this.name,
    required this.designation,
    required this.smsCount,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? 0,
      name: json['displayname'] ?? 'N/A',
      designation: json['position'] ?? 'Company, Designation',
      // API se aa rahe 'Projects' count ko hum 'SMS' count ki tarah istemal kar rahe hain
      smsCount: json['Projects'] ?? 0,
    );
  }
}
