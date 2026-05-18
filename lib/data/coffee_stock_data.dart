class CoffeeStock {
  final String? id;
  final String farmerId;
  final String coffeeType;
  final double quantity;
  final double pricePerKg;
  final String? coffeePicturePath;
  final String description;
  final bool isSold;

  CoffeeStock({
    this.id,
    required this.farmerId,
    required this.coffeeType,
    required this.quantity,
    required this.pricePerKg,
    this.coffeePicturePath,
    this.description = '',
    this.isSold = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'farmer_id': farmerId,
      'coffee_type': coffeeType,
      'quantity': quantity,
      'price_per_kg': pricePerKg,
      'coffee_picture_url': coffeePicturePath,
      'description': description,
      'is_sold': isSold,
    };
  }

  factory CoffeeStock.fromMap(Map<String, dynamic> map) {
    return CoffeeStock(
      id: map['id']?.toString(),
      farmerId: map['farmer_id'] ?? map['farmerId']?.toString() ?? '',
      coffeeType: map['coffee_type'] ?? map['coffeeType'] ?? '',
        quantity: map['quantity'] is num ? (map['quantity'] as num).toDouble() : 0.0,
        pricePerKg: map['price_per_kg'] is num
          ? (map['price_per_kg'] as num).toDouble()
          : (map['pricePerKg'] is num ? (map['pricePerKg'] as num).toDouble() : 0.0),
      coffeePicturePath: map['coffee_picture_url'] ?? map['coffeePicturePath'],
      description: map['description'] ?? '',
      isSold: map['is_sold'] == true || map['is_sold'] == 1 || map['isSold'] == 1 || map['isSold'] == true,
    );
  }
}
