# Purchase Request Response - Quick Reference

## 📋 Current Status

**The feature is working!** Farmers can already respond to purchase requests through the Chat screen.

## 🚀 What You Have

### UI Components (Already Working)
- ✅ **Purchase Requests Screen** - See all requests
- ✅ **Chat Screen** - Send responses
- ✅ **Request Cards** - View details and items

### Database Methods (Updated)

#### Quick Actions
```dart
// Send response to buyer
await DatabaseHelper.instance.respondToPurchaseRequest(
  purchaseRequestMessageId: 5,
  responseText: 'We have stock!',
  farmerId: 2,
  buyerId: 3,
);

// Check if farmer responded
bool hasResponded = await DatabaseHelper.instance
    .hasRespondedToPurchaseRequest(buyerId, farmerId, requestTime);

// Mark as read
await DatabaseHelper.instance.markPurchaseRequestAsRead(messageId);
```

#### Get Data
```dart
// All requests for farmer
List<Message> requests = await DatabaseHelper.instance
    .getPurchaseRequestsForFarmer(farmerId);

// Unread only
List<Message> unread = await DatabaseHelper.instance
    .getUnreadPurchaseRequestsForFarmer(farmerId);

// Full conversation
List<Message> chat = await DatabaseHelper.instance
    .getBuyerFarmerConversation(buyerId, farmerId);

// Request details with user info
Map<String, dynamic>? details = await DatabaseHelper.instance
    .getPurchaseRequestWithDetails(messageId);

// Count of unanswered requests
int count = await DatabaseHelper.instance
    .getUnrespondedPurchaseRequestCount(farmerId);
```

## 📊 Data Flow

```
Buyer creates purchase request
         ↓
Message with isPurchaseRequest=true stored in DB
         ↓
Farmer sees in Purchase Requests screen
         ↓
Farmer taps "Reply to Buyer" → Opens Chat
         ↓
Farmer types and sends message
         ↓
Regular message stored (isPurchaseRequest=false)
         ↓
Buyer sees response in Chat
```

## 🎯 Common Use Cases

### Show notification badge
```dart
int pending = await DatabaseHelper.instance
    .getUnrespondedPurchaseRequestCount(farmerId);
// Show badge if pending > 0
```

### Check response status
```dart
bool responded = await DatabaseHelper.instance
    .hasRespondedToPurchaseRequest(
      buyerId, farmerId, purchaseTime
    );
// Show "Responded" or "Pending" label
```

### Get response history
```dart
List<Message> responses = await DatabaseHelper.instance
    .getPurchaseRequestResponses(
      buyerId, farmerId, purchaseTime
    );
// Show all responses farmer sent
```

### Mark request as read
```dart
await DatabaseHelper.instance
    .markPurchaseRequestAsRead(requestMessageId);
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `lib/data/database_helper.dart` | Database methods |
| `lib/purchase_requests_screen.dart` | Display requests |
| `lib/chat_screen.dart` | Chat/responses UI |
| `lib/data/message_data.dart` | Message model |

## 🔧 Database Methods

### Getting Data
| Method | Returns | Use Case |
|--------|---------|----------|
| `getPurchaseRequestsForFarmer()` | List<Message> | Show all requests |
| `getUnreadPurchaseRequestsForFarmer()` | List<Message> | Show unread only |
| `getPurchaseRequestWithDetails()` | Map | Get full details |
| `getBuyerFarmerConversation()` | List<Message> | Show chat history |
| `getPurchaseRequestsBetween()` | List<Message> | Get requests between users |

### Responding
| Method | Purpose |
|--------|---------|
| `respondToPurchaseRequest()` | Send response |
| `getPurchaseRequestResponses()` | Get all responses |
| `hasRespondedToPurchaseRequest()` | Check if responded |

### Status
| Method | Purpose |
|--------|---------|
| `markPurchaseRequestAsRead()` | Mark as read |
| `getUnrespondedPurchaseRequestCount()` | Count pending |

## 💡 Tips

1. **Always mark as read** when farmer views a request
2. **Check for responses** to avoid duplicate messages
3. **Use quick responses** for common replies
4. **Show badges** for unresponded count
5. **Track timing** for response metrics

## 🎨 UI Enhancements (Optional)

Add these to improve UX:

```
1. Notification badge → Show pending count
2. Status indicator → "Responded" / "Pending" label
3. Quick responses → Pre-populated templates
4. Response time → Track how fast farmer responds
5. Analytics → Farmer's response rate
```

## ✅ Checklist - What's Done

- [x] Purchase request creation (via cart)
- [x] Purchase request display (Purchase Requests screen)
- [x] Response UI (Chat screen)
- [x] Message storage
- [x] Read/unread tracking
- [x] Response tracking methods
- [x] Database helper methods

## ❓ Questions?

Refer to:
- `PURCHASE_REQUEST_IMPLEMENTATION_STATUS.md` - Full details
- `PURCHASE_REQUEST_RESPONSE_GUIDE.md` - Usage guide
- `PURCHASE_REQUEST_CODE_EXAMPLES.md` - Code samples

