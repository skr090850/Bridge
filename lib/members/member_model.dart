class Member {
  final int id;
  final String loginname;
  final String email;
  final String organization;
  final String role;
  final String sex;
  final String photo1;

  Member({
    required this.id,
    required this.loginname,
    required this.email,
    required this.organization,
    required this.role,
    required this.sex,
    required this.photo1,
  });

  // Factory constructor to create a Member from the new JSON data structure
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      loginname: json['loginname'] ?? 'No Name',
      email: json['email'] ?? 'No Email',
      organization: json['organization'] ?? 'No Organization',
      role: json['role'] ?? 'No Role',
      sex: json['sex'] ?? 'N/A',
      photo1: json['photo1'] ?? '',
    );
  }
}

