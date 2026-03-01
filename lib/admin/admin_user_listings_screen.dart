import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import '../../widgets/compact_loader.dart';

class AdminUserListingsScreen extends StatefulWidget {
  final int userId;
  const AdminUserListingsScreen({super.key, required this.userId});

  @override
  State<AdminUserListingsScreen> createState() => _AdminUserListingsScreenState();
}

class _AdminUserListingsScreenState extends State<AdminUserListingsScreen> {
  late Future<List<CoffeeStock>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = DatabaseHelper.instance.getCoffeeStock(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Listings')),
      body: FutureBuilder<List<CoffeeStock>>(
        future: _listingsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text('No listings'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                title: Text(s.coffeeType),
                subtitle: Text('Qty: ${s.quantity}kg • UGX ${s.pricePerKg}/kg'),
                trailing: FutureBuilder<int>(
                  future: DatabaseHelper.instance.getInterestCountForStock(s.id!),
                  builder: (c, snap2) => Text('${snap2.data ?? 0} interests'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
