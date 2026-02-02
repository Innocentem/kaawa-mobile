
class CoffeeStock {
  final int? id;
  final int farmerId;
  final String coffeeType;
  final double quantity;
  final double pricePerKg;

  CoffeeStock({
    this.id,
    required this.farmerId,
    required this.coffeeType,
    required this.quantity,
    required this.pricePerKg,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmerId': farmerId,
      'coffeeType': coffeeType,
      'quantity': quantity,
      'pricePerKg': pricePerKg,
    };
  }

  factory CoffeeStock.fromMap(Map<String, dynamic> map) {
    return CoffeeStock(
      id: map['id'],
      farmerId: map['farmerId'],
      coffeeType: map['coffeeType'],
      quantity: map['quantity'],
      pricePerKg: map['pricePerKg'],
    );
  }
}
