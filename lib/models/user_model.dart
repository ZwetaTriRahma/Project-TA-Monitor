class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? role;
  final String? profileImageUrl;
  final String? nimOrNidn;
  // [NEW] Fields for user account status
  final bool isVerified;
  final bool isDisabled;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.role,
    this.profileImageUrl,
    this.nimOrNidn,
    this.isVerified = false, // Default to false
    this.isDisabled = false, // Default to false
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      nimOrNidn: data['nim_or_nidn'] as String?,
      // [NEW] Read status fields from Firestore, default to false if not present
      isVerified: data['isVerified'] as bool? ?? false,
      isDisabled: data['isDisabled'] as bool? ?? false,
    );
  }
}
