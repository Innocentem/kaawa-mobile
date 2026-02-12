class CoffeeStock {
  final int? id;
  final int farmerId;
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
      'id': id,
      'farmerId': farmerId,
      'coffeeType': coffeeType,
      'quantity': quantity,
      'pricePerKg': pricePerKg,
      'coffeePicturePath': coffeePicturePath,
      'description': description,
      'isSold': isSold ? 1 : 0,
    };
  }

  factory CoffeeStock.fromMap(Map<String, dynamic> map) {
    return CoffeeStock(
      id: map['id'],
      farmerId: map['farmerId'],
      coffeeType: map['coffeeType'],
      quantity: map['quantity'] is int ? (map['quantity'] as int).toDouble() : map['quantity'],
      pricePerKg: map['pricePerKg'] is int ? (map['pricePerKg'] as int).toDouble() : map['pricePerKg'],
      coffeePicturePath: map['coffeePicturePath'],
      description: map['description'] ?? '',
      isSold: map['isSold'] == 1,
    );
  }
}
