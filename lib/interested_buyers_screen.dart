import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/widgets/compact_loader.dart';

class InterestedBuyersScreen extends StatefulWidget {
  final User farmer;
  final CoffeeStock stock;

  const InterestedBuyersScreen({super.key, required this.farmer, required this.stock});

  @override
  State<InterestedBuyersScreen> createState() => _InterestedBuyersScreenState();
}

class _InterestedBuyersScreenState extends State<InterestedBuyersScreen> {
  late Future<List<User>> _buyersFuture;

  @override
  void initState() {
    super.initState();
    // mark interests as seen for this stock (so farmer notification/counts will clear)
    _buyersFuture = DatabaseHelper.instance.markInterestsAsSeenForStock(widget.stock.id!).then((_) {
      // after marking as seen, return the buyers list
      return DatabaseHelper.instance.getInterestedBuyersForStock(widget.stock.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interested Buyers')),
      body: FutureBuilder<List<User>>(
        future: _buyersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: SizedBox(height: 160, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading buyers'))));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final buyers = snapshot.data ?? [];
          if (buyers.isEmpty) return const Center(child: Text('No interested buyers yet.'));
          return ListView.builder(
            itemCount: buyers.length,
            itemBuilder: (context, index) {
              final b = buyers[index];
              return ListTile(
                leading: Hero(tag: b.id != null ? 'avatar-${b.id}' : UniqueKey(), child: Material(type: MaterialType.transparency, child: AppAvatar(filePath: b.profilePicturePath, imageUrl: b.profilePicturePath, size: 44))),
                title: Text(b.fullName),
                subtitle: Text(b.district),
                trailing: IconButton(
                  icon: const Icon(Icons.message),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(currentUser: widget.farmer, otherUser: b, coffeeStock: widget.stock),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
