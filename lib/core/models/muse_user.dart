class MuseUser {
  const MuseUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;

  factory MuseUser.fromJson(Map<String, dynamic> json) {
    return MuseUser(
      id: '${json['id'] ?? ''}',
      email: '${json['email'] ?? ''}',
      displayName: json['displayName']?.toString(),
    );
  }

  String get label {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? email : name;
  }
}
