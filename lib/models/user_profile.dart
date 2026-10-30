class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String avatarUrl;
  final String role;
  final String createdAt;
  final bool notificationsEnabled;

  const UserProfile({
    required this.uid,
    this.email = '',
    this.displayName = '',
    this.phone = '',
    this.avatarUrl = '',
    this.role = 'user',
    this.createdAt = '',
    this.notificationsEnabled = true,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        email: data['email'] as String? ?? '',
        displayName:
            data['displayName'] as String? ?? data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        avatarUrl: data['avatarUrl'] as String? ?? '',
        role: data['role'] as String? ?? 'user',
        createdAt: data['createdAt']?.toString() ?? '',
        notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      );
}
