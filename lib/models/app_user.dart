enum UserRole { citizen, worker }

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.age,
    this.gender,
    this.profileImage,
    this.avatarEmoji,
    this.zone,
    this.phoneVisible,
  });

  final String uid;
  final String? email;
  final UserRole role;
  final String? name;
  final String? phone;
  final int? age;
  final String? gender;
  final String? profileImage;
  final String? avatarEmoji;
  final String? zone;
  final bool? phoneVisible;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final String roleValue = (data['role'] as String? ?? 'citizen')
        .toLowerCase();
    return AppUser(
      uid: uid,
      email: data['email'] as String?,
      role: switch (roleValue) {
        'worker' => UserRole.worker,
        _ => UserRole.citizen,
      },
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      age: (data['age'] as num?)?.toInt(),
      gender: data['gender'] as String?,
      profileImage: data['profile_picture'] as String?,
      avatarEmoji: data['avatar_emoji'] as String?,
      zone: data['zone'] as String?,
      phoneVisible: data['phone_visible'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'role': role.name,
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'profile_picture': profileImage,
      'avatar_emoji': avatarEmoji,
      'zone': zone,
      'phone_visible': phoneVisible,
    };
  }
}
