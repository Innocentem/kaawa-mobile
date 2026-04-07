
class Message {
  final int? id;
  final int senderId;
  final int receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final int? coffeeStockId;
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
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
      'coffeeStockId': coffeeStockId,
      'isPurchaseRequest': isPurchaseRequest ? 1 : 0,
      'purchaseRequestData': purchaseRequestData,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] == 1,
      coffeeStockId: map['coffeeStockId'],
      isPurchaseRequest: (map['isPurchaseRequest'] ?? 0) == 1,
      purchaseRequestData: map['purchaseRequestData'],
    );
  }
}
