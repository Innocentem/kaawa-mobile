import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';

class UserSelectionScreen extends StatefulWidget {
  final kaawa.User currentUser;
  final kaawa.UserType targetType;

  const UserSelectionScreen({
    super.key,
    required this.currentUser,
    required this.targetType,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  late Future<List<kaawa.User>> _usersFuture;
  final _searchController = TextEditingController();
  List<kaawa.User> _allUsers = [];
  List<kaawa.User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _usersFuture = SupabaseService.instance.getAllProfiles();
    _searchController.addListener(_filterUsers);
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allUsers.where((u) {
      return u.userType == widget.targetType &&
          u.id != widget.currentUser.id &&
          (u.fullName.toLowerCase().contains(query) ||
              u.district.toLowerCase().contains(query));
    }).toList();

    if (mounted) {
      setState(() {
        _filteredUsers = filtered;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFarmer = widget.targetType == kaawa.UserType.farmer;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
              elevation: 0,
              title: Image.asset(
                'assets/icons/pngwing.png',
                height: 32,
                fit: BoxFit.contain,
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or district...',
                        prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<kaawa.User>>(
                    future: _usersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          _allUsers.isEmpty) {
                        return const Center(child: CompactLoader());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasData && _allUsers.isEmpty) {
                        _allUsers = snapshot.data!;
                        // Use microtask or postFrameCallback to avoid setState during build
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _filterUsers();
                        });
                      }

                      if (_filteredUsers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 80,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ${isFarmer ? 'farmers' : 'buyers'} found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Hero(
                                tag: 'user_avatar_${user.id}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.primaryColor.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: AppAvatar(
                                    filePath: user.profilePicturePath,
                                    imageUrl: user.profilePicturePath,
                                    size: 50,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: theme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(user.district),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 20,
                                  color: theme.primaryColor,
                                ),
                              ),
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      currentUser: widget.currentUser,
                                      otherUser: user,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
