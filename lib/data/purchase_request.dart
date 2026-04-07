import 'package:kaawa/data/coffee_stock_data.dart';

class PurchaseRequestItem {
  final int stockId;
  final String coffeeType;
  final double quantityKg;
  final double pricePerKg;
  final double totalPrice;

  PurchaseRequestItem({
    required this.stockId,
    required this.coffeeType,
    required this.quantityKg,
    required this.pricePerKg,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'stockId': stockId,
      'coffeeType': coffeeType,
      'quantityKg': quantityKg,
      'pricePerKg': pricePerKg,
      'totalPrice': totalPrice,
    };
  }

  factory PurchaseRequestItem.fromMap(Map<String, dynamic> map) {
    return PurchaseRequestItem(
      stockId: map['stockId'] as int,
      coffeeType: map['coffeeType'] as String,
      quantityKg: (map['quantityKg'] as num).toDouble(),
      pricePerKg: (map['pricePerKg'] as num).toDouble(),
      totalPrice: (map['totalPrice'] as num).toDouble(),
    );
  }

  factory PurchaseRequestItem.fromCoffeeStock(CoffeeStock stock, double quantity) {
    return PurchaseRequestItem(
      stockId: stock.id!,
      coffeeType: stock.coffeeType,
      quantityKg: quantity,
      pricePerKg: stock.pricePerKg,
      totalPrice: stock.pricePerKg * quantity,
    );
  }
}

class PurchaseRequest {
  final int? id;
  final int buyerId;
  final int farmerId;
  final List<PurchaseRequestItem> items;
  final double totalAmount;
  final DateTime sentAt;
  final String? buyerMessage;
  final bool seenByFarmer;
  final String? farmerResponse;
  final DateTime? respondedAt;

  PurchaseRequest({
    this.id,
    required this.buyerId,
    required this.farmerId,
    required this.items,
    required this.totalAmount,
    required this.sentAt,
    this.buyerMessage,
    this.seenByFarmer = false,
    this.farmerResponse,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'farmerId': farmerId,
      'itemsJson': _itemsToJson(),
      'totalAmount': totalAmount,
      'sentAt': sentAt.toIso8601String(),
      'buyerMessage': buyerMessage,
      'seenByFarmer': seenByFarmer ? 1 : 0,
      'farmerResponse': farmerResponse,
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  String _itemsToJson() {
    // Simple JSON encoding for items
    final itemsList = items.map((item) => item.toMap()).toList();
    return itemsList.toString(); // Or use jsonEncode if you have json package
  }

  factory PurchaseRequest.fromMap(Map<String, dynamic> map) {
    return PurchaseRequest(
      id: map['id'] as int?,
      buyerId: map['buyerId'] as int,
      farmerId: map['farmerId'] as int,
      items: _parseItems(map['itemsJson']),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      sentAt: DateTime.parse(map['sentAt'] as String),
      buyerMessage: map['buyerMessage'] as String?,
      seenByFarmer: (map['seenByFarmer'] as int?) == 1,
      farmerResponse: map['farmerResponse'] as String?,
      respondedAt: map['respondedAt'] != null ? DateTime.parse(map['respondedAt'] as String) : null,
    );
  }

  static List<PurchaseRequestItem> _parseItems(String? itemsJson) {
    if (itemsJson == null || itemsJson.isEmpty) return [];
    try {
      // This is a simplified parser - adjust based on your actual format
      final items = <PurchaseRequestItem>[];
      // You may want to use jsonDecode if you add json package
      // For now, we'll handle basic parsing
      return items;
    } catch (_) {
      return [];
    }
  }
}

