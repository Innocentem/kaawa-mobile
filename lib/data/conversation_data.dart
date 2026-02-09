
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/message_data.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';

class Conversation {
  final User otherUser;
  final Message lastMessage;
  final CoffeeStock? coffeeStock;

  Conversation({
    required this.otherUser,
    required this.lastMessage,
    this.coffeeStock,
  });
}
