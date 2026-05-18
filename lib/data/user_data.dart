enum UserType { farmer, buyer, admin }

class User {
  final String? id;
  final String fullName;
  final String phoneNumber;
  final String district;
  final String password;
  final UserType userType;
  final String? profilePicturePath;
  final double? latitude;
  final double? longitude;
  // whether user must change password on next login
  final bool mustChangePassword;
  // optional suspension until ISO timestamp
  final DateTime? suspendedUntil;
  // optional suspension reason provided by admin
  final String? suspensionReason;

  // Farmer-specific fields
  final String? village;

  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.district,
    required this.password,
    required this.userType,
    this.profilePicturePath,
    this.latitude,
    this.longitude,
    this.village,
    this.mustChangePassword = false,
    this.suspendedUntil,
    this.suspensionReason,
  });

  bool get isSuspended {
    if (userType == UserType.admin) return false;
    final until = suspendedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration? get suspensionRemaining {
    if (!isSuspended) return null;
    return suspendedUntil!.difference(DateTime.now());
  }

  String? get suspensionRemainingText {
    final remaining = suspensionRemaining;
    if (remaining == null) return null;
    final totalMinutes = remaining.inMinutes.clamp(0, 1 << 30);
    final days = totalMinutes ~/ (60 * 24);
    final hours = (totalMinutes % (60 * 24)) ~/ 60;
    final minutes = totalMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'district': district,
      'user_type': userType.name,
      'profile_picture_url': profilePicturePath,
      'latitude': latitude,
      'longitude': longitude,
      'village': village,
      'must_change_password': mustChangePassword,
      'suspended_until': suspendedUntil?.toIso8601String(),
      'suspension_reason': suspensionReason,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toString(),
      fullName: map['fullName'] ?? map['full_name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone_number'] ?? '',
      district: map['district'] ?? '',
      password: map['password'] ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.toString() == map['userType'] || e.name == map['user_type'],
        orElse: () => UserType.buyer,
      ),
      profilePicturePath: map['profilePicturePath'] ?? map['profile_picture_url'],
      latitude: map['latitude'] is num ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] is num ? (map['longitude'] as num).toDouble() : null,
      village: map['village'],
      mustChangePassword: map['mustChangePassword'] == 1 || map['mustChangePassword'] == true || map['must_change_password'] == true,
      suspendedUntil: map['suspendedUntil'] != null ? DateTime.tryParse(map['suspendedUntil'].toString()) : (map['suspended_until'] != null ? DateTime.tryParse(map['suspended_until'].toString()) : null),
      suspensionReason: map['suspensionReason'] ?? map['suspension_reason'],
    );
  }
}
