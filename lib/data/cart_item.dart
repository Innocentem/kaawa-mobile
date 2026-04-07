import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/user_data.dart';

class CartItem {
  final int id;
  final int buyerId;
  final CoffeeStock stock;
  final User farmer;
  final double quantityKg;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.buyerId,
    required this.stock,
    required this.farmer,
    required this.quantityKg,
    required this.addedAt,
  });

  double get totalPrice => stock.pricePerKg * quantityKg;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'stockId': stock.id,
      'farmerId': farmer.id,
      'quantityKg': quantityKg,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

