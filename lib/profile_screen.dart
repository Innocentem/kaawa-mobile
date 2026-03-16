import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/manage_stock_screen.dart';
import 'package:kaawa/write_review_screen.dart';
import 'package:kaawa/view_reviews_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/activity_log_screen.dart';
import 'package:kaawa/contact_admin_screen.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileScreen extends StatefulWidget {
  final User currentUser;
  final User profileOwner;

  const ProfileScreen({super.key, required this.currentUser, required this.profileOwner});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _hasReviewed = false;
  bool _reviewStatusLoaded = false;

  late User _profileOwner;
  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _districtController;
  late TextEditingController _villageController;
  String? _profilePicturePath;

  bool get _isOwnProfile => widget.currentUser.id == _profileOwner.id;

  @override
  void initState() {
    super.initState();
    _profileOwner = widget.profileOwner;
    _initializeControllers(_profileOwner);
    _loadReviewStatus();
  }

  Future<void> _loadReviewStatus() async {
    if (_isOwnProfile || _profileOwner.userType == UserType.admin) return;
    final exists = await DatabaseHelper.instance.hasReviewByUser(widget.currentUser.id!, _profileOwner.id!);
    if (!mounted) return;
    setState(() {
      _hasReviewed = exists;
      _reviewStatusLoaded = true;
    });
  }

  void _initializeControllers(User user) {
    _fullNameController = TextEditingController(text: user.fullName);
    _phoneNumberController = TextEditingController(text: user.phoneNumber);
    _districtController = TextEditingController(text: user.district);
    _villageController = TextEditingController(text: user.village);
    _profilePicturePath = user.profilePicturePath;
  }

  void _toggleEditing() {
    if (!_isOwnProfile) return;
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _initializeControllers(_profileOwner);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      setState(() {
        _profilePicturePath = savedImage.path;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedUser = User(
      id: _profileOwner.id,
      fullName: _fullNameController.text,
      phoneNumber: _phoneNumberController.text,
      password: _profileOwner.password, // Keep the existing password
      district: _districtController.text,
      userType: _profileOwner.userType,
      profilePicturePath: _profilePicturePath,
      latitude: _profileOwner.latitude,
      longitude: _profileOwner.longitude,
      village: _villageController.text,
      mustChangePassword: _profileOwner.mustChangePassword,
      suspendedUntil: _profileOwner.suspendedUntil,
      suspensionReason: _profileOwner.suspensionReason,
    );

    await DatabaseHelper.instance.updateUser(updatedUser);
    final refreshed = await DatabaseHelper.instance.getUserById(updatedUser.id!);

    setState(() {
      _isEditing = false;
      _profileOwner = refreshed ?? updatedUser;
      _initializeControllers(_profileOwner);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  void _openActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActivityLogScreen(userId: _profileOwner.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: Icon(_isEditing ? Icons.cancel : Icons.settings),
              onPressed: _toggleEditing,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar and name
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Hero(
                            tag: _profileOwner.id != null ? 'avatar-${_profileOwner.id}' : UniqueKey(),
                            child: Material(
                              type: MaterialType.transparency,
                              child: AppAvatar(
                                filePath: _profilePicturePath,
                                imageUrl: _profilePicturePath,
                                size: 72,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  tooltip: 'Change profile photo',
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profileOwner.fullName.isNotEmpty ? _profileOwner.fullName : 'No name',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      // Activity summary (listings / interests / conversations + member since)
                      // XP/badges removed per product decision. Use StreamBuilder to keep values live.
                      if (_profileOwner.id != null)
                        StreamBuilder<Map<String, dynamic>>(
                          stream: DatabaseHelper.instance.getUserActivityStream(_profileOwner.id!),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text('Loading activity...', style: theme.textTheme.bodySmall);
                            }
                            final data = snapshot.data!;
                            final listings = data['listingsCount'] ?? 0;
                            final interests = data['interestsCount'] ?? 0;
                            final conversations = data['conversationsCount'] ?? 0;
                            final earliestIso = data['earliestActivityIso'] as String?;
                            final memberSince = earliestIso != null ? DateFormat.yMMMd().format(DateTime.parse(earliestIso)) : 'Unknown';

                            return Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _smallStat('$listings', 'Listings', theme),
                                    const SizedBox(width: 12),
                                    _smallStat('$interests', 'Interests', theme),
                                    const SizedBox(width: 12),
                                    _smallStat('$conversations', 'Convos', theme),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Member since $memberSince', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: _openActivityLog,
                                  child: Text('View activity log', style: theme.textTheme.labelLarge),
                                ),
                              ],
                            );
                          },
                        )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Removed the copied "badges" UI from testscreen/profile.dart.
            // The app's User model already has `xp` and `badgesCount` but the
            // previous large badges widgets were unnecessary for the app's flow.
            // We keep the compact XP text near the avatar and remove the extra
            // cards to reduce visual clutter.
            const SizedBox(height: 20),

            // Editable form fields
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  _buildTextField(_fullNameController, 'Full Name', isEnabled: _isEditing),
                  _buildTextField(_phoneNumberController, 'Phone Number', isEnabled: _isEditing, keyboardType: TextInputType.phone),
                  _buildTextField(_districtController, 'District', isEnabled: _isEditing),
                  if (_profileOwner.userType == UserType.farmer) ..._farmerFields,
                  const SizedBox(height: 16),

                  if (_isOwnProfile && _isEditing)
                    ElevatedButton(onPressed: _saveChanges, child: const Text('Save Changes')),

                  if (_isOwnProfile && _profileOwner.userType == UserType.farmer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                          icon: const Icon(Icons.inventory),
                          label: const Text('Manage Coffee Stock'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ManageStockScreen(farmer: _profileOwner),
                              ),
                            );
                          }),
                    ),

                  if (_isOwnProfile && _profileOwner.userType != UserType.admin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Message Admin'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContactAdminScreen(currentUser: widget.currentUser),
                            ),
                          );
                        },
                      ),
                    ),

                  if (!_isOwnProfile && _profileOwner.userType != UserType.admin)
                    ElevatedButton(
                      onPressed: !_reviewStatusLoaded || _hasReviewed
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WriteReviewScreen(
                                    reviewer: widget.currentUser,
                                    reviewedUser: _profileOwner,
                                  ),
                                ),
                              );
                              await _loadReviewStatus();
                            },
                      child: Text(_hasReviewed ? 'Review already submitted' : 'Write a Review'),
                    ),

                  const SizedBox(height: 12),

                  if (_profileOwner.userType != UserType.admin)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewReviewsScreen(
                              reviewedUser: _profileOwner,
                              currentUser: widget.currentUser,
                              onOpenProfile: (reviewer) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(currentUser: widget.currentUser, profileOwner: reviewer),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('View Reviews'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isEnabled = true, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !isEnabled,
          fillColor: !isEnabled ? (Theme.of(context).colorScheme.surfaceVariant ?? Theme.of(context).colorScheme.surface.withAlpha((0.06*255).round())) : null,
        ),
        readOnly: !isEnabled,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  List<Widget> get _farmerFields {
    return [
      _buildTextField(_villageController, 'Village', isEnabled: _isEditing),
    ];
  }

  Widget _smallStat(String value, String label, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
