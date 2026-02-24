enum UserType { farmer, buyer, admin }

class User {
  final int? id;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'district': district,
      'password': password,
      'userType': userType.toString(),
      'profilePicturePath': profilePicturePath,
      'latitude': latitude,
      'longitude': longitude,
      'village': village,
      'mustChangePassword': mustChangePassword ? 1 : 0,
      'suspendedUntil': suspendedUntil?.toIso8601String(),
      'suspensionReason': suspensionReason,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      district: map['district'],
      password: map['password'],
      userType: UserType.values.firstWhere((e) => e.toString() == map['userType']),
      profilePicturePath: map['profilePicturePath'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      village: map['village'],
      mustChangePassword: (map['mustChangePassword'] == null) ? false : (map['mustChangePassword'] == 1 || map['mustChangePassword'] == true),
      suspendedUntil: (map['suspendedUntil'] == null) ? null : DateTime.tryParse(map['suspendedUntil'].toString()),
      suspensionReason: map['suspensionReason']?.toString(),
    );
  }
}
