import 'package:kaawa/utils/date_utils.dart';


class Message {
  final String? id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? coffeeStockId;
  final bool isPurchaseRequest;
  final String? purchaseRequestData; // JSON encoded cart items

  Message({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.coffeeStockId,
    this.isPurchaseRequest = false,
    this.purchaseRequestData,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'coffee_stock_id': coffeeStockId,
      'is_purchase_request': isPurchaseRequest,
      'purchase_request_data': purchaseRequestData,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id']?.toString(),
      senderId: map['sender_id'] ?? map['senderId']?.toString() ?? '',
      receiverId: map['receiver_id'] ?? map['receiverId']?.toString() ?? '',
      text: map['text'] ?? '',
      timestamp: parseDateSafe(map['created_at'] ?? map['timestamp']) ?? DateTime.now(),
      isRead: map['is_read'] == true || map['isRead'] == 1,
      coffeeStockId: map['coffee_stock_id']?.toString() ?? map['coffeeStockId']?.toString(),
      isPurchaseRequest: map['is_purchase_request'] == true || map['isPurchaseRequest'] == 1,
      purchaseRequestData: map['purchase_request_data'] ?? map['purchaseRequestData'],
    );
  }
}
