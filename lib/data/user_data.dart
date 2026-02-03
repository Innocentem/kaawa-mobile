
enum UserType { farmer, buyer }

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
    );
  }
}
