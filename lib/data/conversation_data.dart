import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/coffee_stock_data.dart';

class Conversation {
  final kaawa.User otherUser;
  final Message lastMessage;
  final CoffeeStock? coffeeStock;

  Conversation({
    required this.otherUser,
    required this.lastMessage,
    this.coffeeStock,
  });
}
