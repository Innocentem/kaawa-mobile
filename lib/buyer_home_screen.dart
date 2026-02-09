
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/conversations_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/welcome_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';

class BuyerHomeScreen extends StatefulWidget {
  final User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with TickerProviderStateMixin {
  late Future<List<CoffeeStock>> _coffeeStockFuture;
  List<CoffeeStock> _allCoffeeStock = [];
  List<CoffeeStock> _filteredCoffeeStock = [];
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _coffeeStockFuture = _getCoffeeStock();
    _searchController.addListener(_filterCoffeeStock);
    _getUnreadMessageCount();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await DatabaseHelper.instance.getUnreadMessageCount(widget.buyer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    return await DatabaseHelper.instance.getAllCoffeeStock();
  }

  void _filterCoffeeStock() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCoffeeStock = _allCoffeeStock.where((stock) {
        final coffeeTypeLower = stock.coffeeType.toLowerCase();
        return coffeeTypeLower.contains(query);
      }).toList();
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $phoneNumber')),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.buyer.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConversationsScreen(currentUser: widget.buyer),
                    ),
                  ).then((_) => _getUnreadMessageCount());
                },
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadMessageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: widget.buyer),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Coffee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tap on a listing to view farmer details. Use the message icon to inquire or the cart icon to buy.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by coffee type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CoffeeStock>>(
                future: _coffeeStockFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading coffee stock.'));
                  } else {
                    _allCoffeeStock = snapshot.data ?? [];
                    _filteredCoffeeStock = List.from(_allCoffeeStock);
                    return FadeTransition(
                      opacity: _animation,
                      child: _filteredCoffeeStock.isEmpty && _searchController.text.isNotEmpty
                          ? const Center(child: Text('No coffee stock found.'))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.6,
                              ),
                              itemCount: _filteredCoffeeStock.length,
                              itemBuilder: (context, index) {
                                final stock = _filteredCoffeeStock[index];
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: () async {
                                      final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: farmer!),
                                        ),
                                      );
                                    },
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 1,
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                              child: stock.coffeePicturePath != null
                                                  ? Image.file(File(stock.coffeePicturePath!), fit: BoxFit.cover)
                                                  : const Icon(Icons.local_cafe, size: 50),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stock.coffeeType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text('${stock.quantity} kg available', overflow: TextOverflow.ellipsis),
                                                Text('Price: UGX ${stock.pricePerKg}/kg', overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.message),
                                                onPressed: () async {
                                                  final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ChatScreen(
                                                        currentUser: widget.buyer,
                                                        otherUser: farmer!,
                                                        coffeeStock: stock,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.shopping_cart),
                                                onPressed: () async {
                                                  final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ChatScreen(
                                                        currentUser: widget.buyer,
                                                        otherUser: farmer!,
                                                        initialMessage: 'I would like to buy your ${stock.coffeeType}.',
                                                        coffeeStock: stock,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
