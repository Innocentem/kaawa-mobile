
enum UserType { farmer, buyer }

class User {
  final int? id;
  final String fullName;
  final String phoneNumber;
  final String district;
  final UserType userType;
  final String? profilePicturePath;
  final double? latitude;
  final double? longitude;

  // Farmer-specific fields
  final String? village;
  final String? coffeeType;
  final double? quantity;
  final double? pricePerKg;
  final String? coffeePicturePath;

  // Buyer-specific fields
  final String? coffeeTypeSought;

  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.district,
    required this.userType,
    this.profilePicturePath,
    this.latitude,
    this.longitude,
    this.village,
    this.coffeeType,
    this.quantity,
    this.pricePerKg,
    this.coffeePicturePath,
    this.coffeeTypeSought,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'district': district,
      'userType': userType.toString(),
      'profilePicturePath': profilePicturePath,
      'latitude': latitude,
      'longitude': longitude,
      'village': village,
      'coffeeType': coffeeType,
      'quantity': quantity,
      'pricePerKg': pricePerKg,
      'coffeePicturePath': coffeePicturePath,
      'coffeeTypeSought': coffeeTypeSought,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      district: map['district'],
      userType: UserType.values.firstWhere((e) => e.toString() == map['userType']),
      profilePicturePath: map['profilePicturePath'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      village: map['village'],
      coffeeType: map['coffeeType'],
      quantity: map['quantity'],
      pricePerKg: map['pricePerKg'],
      coffeePicturePath: map['coffeePicturePath'],
      coffeeTypeSought: map['coffeeTypeSought'],
    );
  }
}
