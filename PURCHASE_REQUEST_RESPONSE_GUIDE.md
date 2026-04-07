# Purchase Request Response Feature Guide

## Overview
The Kaawa mobile app now has comprehensive database support for farmers to respond to purchase requests from potential buyers. This guide explains how the system works and how to implement UI for responding to these requests.

## Current Flow

### 1. Purchase Request Creation (Buyer Side)
- Buyers add items to their cart
- Buyers submit a purchase request with JSON-encoded cart items
- A `Message` is created with:
  - `isPurchaseRequest = true`
  - `purchaseRequestData` containing JSON-encoded items
  - `senderId = buyerId`
  - `receiverId = farmerId`

### 2. Purchase Requests Screen (Farmer Side)
- Located in: `lib/purchase_requests_screen.dart`
- Displays all purchase requests sent to the farmer
- Shows buyer info, items, total amount, and buyer message
- "Reply to Buyer" button opens the chat screen

### 3. Chat Screen (Response)
- Located in: `lib/chat_screen.dart`
- Displays the conversation between buyer and farmer
- Existing purchase request messages show as special cards
- Farmer can send regular text messages as responses
- The system already tracks responses through the message history

## Database Helper Methods

### Getting Purchase Requests

#### Get all purchase requests for a farmer
```dart
Future<List<Message>> getPurchaseRequestsForFarmer(int farmerId)
```
- Returns all purchase requests received by the farmer
- Ordered by most recent first

#### Get unread purchase requests for a farmer
```dart
Future<List<Message>> getUnreadPurchaseRequestsForFarmer(int farmerId)
```
- Returns only unread purchase requests
- Useful for notifications

#### Get a specific purchase request with full details
```dart
Future<Map<String, dynamic>?> getPurchaseRequestWithDetails(int messageId)
```
- Returns a map with:
  - Message details (id, text, timestamp, isRead, purchaseRequestData)
  - Buyer info (id, fullName, phoneNumber, district, userType, profilePicturePath)
  - Farmer info (id, fullName, phoneNumber, district, userType, profilePicturePath)

#### Get conversation history between buyer and farmer
```dart
Future<List<Message>> getBuyerFarmerConversation(int buyerId, int farmerId)
```
- Returns all messages between the two users
- Includes both regular messages and purchase requests
- Ordered by timestamp ascending

#### Get all purchase requests between specific buyer and farmer
```dart
Future<List<Message>> getPurchaseRequestsBetween(int buyerId, int farmerId)
```
- Returns only purchase request messages
- Useful for showing request history

### Responding to Purchase Requests

#### Send a response message
```dart
Future<int> respondToPurchaseRequest(
  int purchaseRequestMessageId,
  String responseText,
  int farmerId,
  int buyerId
)
```
- Creates a new message from farmer to buyer
- Returns the ID of the inserted message
- The response is a regular message (not flagged as isPurchaseRequest)

Example usage:
```dart
final messageId = await DatabaseHelper.instance.respondToPurchaseRequest(
  purchaseRequestMessageId: 5,
  responseText: 'We can provide 50kg at UGX 5000/kg. Available next week.',
  farmerId: 2,
  buyerId: 3,
);
```

#### Get responses to a purchase request
```dart
Future<List<Message>> getPurchaseRequestResponses(
  int buyerId,
  int farmerId,
  DateTime purchaseRequestTime
)
```
- Returns all messages sent by farmer to buyer after the purchase request
- Useful for tracking farmer responses to a specific request

#### Check if farmer has responded
```dart
Future<bool> hasRespondedToPurchaseRequest(
  int buyerId,
  int farmerId,
  DateTime purchaseRequestTime
)
```
- Returns true if farmer has sent any message to this buyer after the request
- Useful for UI indicators

### Purchase Request Status

#### Mark purchase request as read
```dart
Future<void> markPurchaseRequestAsRead(int messageId)
```
- Sets the `isRead` flag to 1
- Called automatically when farmer opens the purchase request

#### Get count of unresponded purchase requests
```dart
Future<int> getUnrespondedPurchaseRequestCount(int farmerId)
```
- Returns number of purchase requests that don't have any farmer responses
- Useful for notifications badge

## Current UI Implementation

### Purchase Requests Screen
The `PurchaseRequestsScreen` widget already displays:
1. ✅ List of all purchase requests for a farmer
2. ✅ Buyer information with avatar
3. ✅ Itemized cart contents
4. ✅ Total amount
5. ✅ Buyer's message
6. ✅ Timestamp
7. ✅ "Reply to Buyer" button that opens chat

### Chat Screen
The `ChatScreen` widget already supports:
1. ✅ Displaying purchase request messages with special formatting
2. ✅ Showing item details in the purchase request bubble
3. ✅ Sending and receiving regular messages
4. ✅ Auto-marking messages as read
5. ✅ Conversation history between users

## How to Use in Your App

### Example: Checking for new purchase requests and responding

```dart
import 'package:kaawa/data/database_helper.dart';

// Get unread purchase requests
final unreadRequests = await DatabaseHelper.instance
    .getUnreadPurchaseRequestsForFarmer(farmerId);

for (final request in unreadRequests) {
  print('New purchase request from buyer ${request.senderId}');
  
  // Get buyer info
  final buyer = await DatabaseHelper.instance.getUserById(request.senderId);
  print('Buyer: ${buyer?.fullName}');
  
  // Send response
  final responseId = await DatabaseHelper.instance.respondToPurchaseRequest(
    purchaseRequestMessageId: request.id!,
    responseText: 'Thank you for your interest. We have stock available.',
    farmerId: farmerId,
    buyerId: request.senderId,
  );
  
  // Mark as read
  await DatabaseHelper.instance.markPurchaseRequestAsRead(request.id!);
}
```

### Example: Checking unresponded requests for notifications

```dart
// Get count of unresponded requests
final unrespondedCount = await DatabaseHelper.instance
    .getUnrespondedPurchaseRequestCount(farmerId);

if (unrespondedCount > 0) {
  // Show notification badge
  showBadge(count: unrespondedCount);
}
```

### Example: Getting full conversation with a buyer

```dart
// Get all messages between farmer and buyer
final conversation = await DatabaseHelper.instance
    .getBuyerFarmerConversation(buyerId, farmerId);

// Separate purchase requests from responses
final purchaseRequests = conversation
    .where((msg) => msg.isPurchaseRequest)
    .toList();

final responses = conversation
    .where((msg) => !msg.isPurchaseRequest)
    .toList();
```

## Integration Points

### 1. Farmer Home Screen
Could show:
- Badge count of unresponded purchase requests
- Quick stats using `getUnrespondedPurchaseRequestCount()`

### 2. Purchase Requests Screen
Already implemented - shows all requests with reply button

### 3. Chat Screen
Already implemented - allows responding through regular messaging

### 4. Notifications
Could use:
- `getUnreadPurchaseRequestsForFarmer()` - for unread count
- `getUnrespondedPurchaseRequestCount()` - for unanswered requests

### 5. Activity Log
Could use:
- `getBuyerFarmerConversation()` - to show interaction history
- `getPurchaseRequestResponses()` - to track response times

## Data Structure

### Purchase Request Message
```dart
Message(
  id: 1,
  senderId: 3,        // buyer id
  receiverId: 2,      // farmer id
  text: 'I need coffee',
  timestamp: DateTime.now(),
  isRead: 0,
  coffeeStockId: null,
  isPurchaseRequest: 1,
  purchaseRequestData: '''{"items": [...], "totalAmount": 50000}''',
)
```

### Purchase Request Data (JSON in purchaseRequestData field)
```json
{
  "items": [
    {
      "coffeeType": "Arabica",
      "quantityKg": 10,
      "pricePerKg": 5000,
      "totalPrice": 50000
    }
  ],
  "totalAmount": 50000
}
```

## Best Practices

1. **Always mark as read** - Call `markPurchaseRequestAsRead()` when farmer views a request
2. **Check for responses** - Use `hasRespondedToPurchaseRequest()` to avoid duplicate responses
3. **Show status** - Use `getUnrespondedPurchaseRequestCount()` for notifications
4. **Full context** - Use `getPurchaseRequestWithDetails()` when you need complete info
5. **Conversation flow** - Use `getBuyerFarmerConversation()` to show full interaction history

## Notes

- The system uses the existing `messages` table with special flags
- Purchase request responses are regular messages (isPurchaseRequest = false)
- All timestamps are stored as ISO 8601 strings
- The system is designed to work offline - all data is stored locally in SQLite
- UI for responding is already implemented in `ChatScreen`

