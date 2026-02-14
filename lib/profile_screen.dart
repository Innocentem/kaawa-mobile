import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/write_review_screen.dart';
import 'package:kaawa_mobile/view_reviews_screen.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/activity_log_screen.dart';

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

  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _districtController;
  late TextEditingController _villageController;
  String? _profilePicturePath;

  bool get _isOwnProfile => widget.currentUser.id == widget.profileOwner.id;

  @override
  void initState() {
    super.initState();
    _initializeControllers(widget.profileOwner);
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
        _initializeControllers(widget.profileOwner);
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
      id: widget.profileOwner.id,
      fullName: _fullNameController.text,
      phoneNumber: _phoneNumberController.text,
      password: widget.profileOwner.password, // Keep the existing password
      district: _districtController.text,
      userType: widget.profileOwner.userType,
      profilePicturePath: _profilePicturePath,
      latitude: widget.profileOwner.latitude,
      longitude: widget.profileOwner.longitude,
      village: _villageController.text,
    );

    await DatabaseHelper.instance.updateUser(updatedUser);

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  void _openActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActivityLogScreen(userId: widget.profileOwner.id!)),
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
                      Hero(
                        tag: widget.profileOwner.id != null ? 'avatar-${widget.profileOwner.id}' : UniqueKey(),
                        child: AppAvatar(
                          filePath: _profilePicturePath,
                          imageUrl: _profilePicturePath,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.profileOwner.fullName.isNotEmpty ? widget.profileOwner.fullName : 'No name',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      // Activity summary (listings / interests / conversations + member since)
                      // XP/badges removed per product decision. Use StreamBuilder to keep values live.
                      if (widget.profileOwner.id != null)
                        StreamBuilder<Map<String, dynamic>>(
                          stream: DatabaseHelper.instance.getUserActivityStream(widget.profileOwner.id!),
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
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 100,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
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
                  if (widget.profileOwner.userType == UserType.farmer) ..._farmerFields,
                  const SizedBox(height: 16),

                  if (_isOwnProfile && _isEditing)
                    ElevatedButton(onPressed: _saveChanges, child: const Text('Save Changes')),

                  if (_isOwnProfile && widget.profileOwner.userType == UserType.farmer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                          icon: const Icon(Icons.inventory),
                          label: const Text('Manage Coffee Stock'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ManageStockScreen(farmer: widget.profileOwner),
                              ),
                            );
                          }),
                    ),

                  if (!_isOwnProfile)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WriteReviewScreen(
                              reviewer: widget.currentUser,
                              reviewedUser: widget.profileOwner,
                            ),
                          ),
                        );
                      },
                      child: const Text('Write a Review'),
                    ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewReviewsScreen(
                            reviewedUser: widget.profileOwner,
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
          fillColor: Colors.grey[200],
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
