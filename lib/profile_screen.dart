import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/manage_stock_screen.dart';
import 'package:kaawa/write_review_screen.dart';
import 'package:kaawa/view_reviews_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/activity_log_screen.dart';
import 'package:kaawa/contact_admin_screen.dart';
import 'package:kaawa/theme/theme.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileScreen extends StatefulWidget {
  final kaawa.User currentUser;
  final kaawa.User profileOwner;

  const ProfileScreen(
      {super.key, required this.currentUser, required this.profileOwner});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _hasReviewed = false;
  bool _reviewStatusLoaded = false;

  late kaawa.User _profileOwner;
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
    if (_isOwnProfile || _profileOwner.userType == kaawa.UserType.admin) return;
    final exists = await SupabaseService.instance
        .hasReviewByUser(widget.currentUser.id!, _profileOwner.id!);
    if (!mounted) return;
    setState(() {
      _hasReviewed = exists;
      _reviewStatusLoaded = true;
    });
  }

  void _initializeControllers(kaawa.User user) {
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
      final savedImage =
          await File(pickedFile.path).copy('${appDir.path}/$fileName');

      setState(() {
        _profilePicturePath = savedImage.path;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    String? finalImagePath = _profilePicturePath;
    var uploadFailed = false;
    if (_profilePicturePath != null &&
        (_profilePicturePath!.startsWith('/') ||
            _profilePicturePath!.startsWith('file:'))) {
      final file = File(_profilePicturePath!);
      if (await file.exists()) {
        try {
          final publicUrl = await SupabaseService.instance.uploadImage(
            'kaawa-media',
            'profiles/${_profileOwner.id}',
            file,
            oldUrl: _profileOwner.profilePicturePath,
          );
          if (publicUrl != null) {
            finalImagePath = publicUrl;
            setState(() {
              _profilePicturePath = publicUrl;
            });
          } else {
            uploadFailed = true;
          }
        } catch (e) {
          uploadFailed = true;
        }
      } else {
        uploadFailed = true;
      }
    }

    if (uploadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload profile picture. Please try again.'),
        ),
      );
      return;
    }

    final updatedUser = kaawa.User(
      id: _profileOwner.id,
      fullName: _fullNameController.text,
      phoneNumber: _phoneNumberController.text,
      password: _profileOwner.password, // Keep the existing password
      district: _districtController.text,
      userType: _profileOwner.userType,
      profilePicturePath: finalImagePath,
      latitude: _profileOwner.latitude,
      longitude: _profileOwner.longitude,
      village: _villageController.text,
      mustChangePassword: _profileOwner.mustChangePassword,
      suspendedUntil: _profileOwner.suspendedUntil,
      suspensionReason: _profileOwner.suspensionReason,
    );

    await SupabaseService.instance.updateProfile(updatedUser);
    final refreshed =
        await SupabaseService.instance.getProfile(updatedUser.id!);

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
      MaterialPageRoute(
          builder: (context) => ActivityLogScreen(userId: _profileOwner.id!)),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
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
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: _profileOwner.id != null
                            ? 'avatar-${_profileOwner.id}'
                            : UniqueKey(),
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                              onPressed: () =>
                                  _showImageSourceActionSheet(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profileOwner.fullName.isNotEmpty
                        ? _profileOwner.fullName
                        : 'No name',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (_profileOwner.id != null)
                    StreamBuilder<Map<String, dynamic>>(
                      stream: SupabaseService.instance
                          .getUserActivityStream(_profileOwner.id!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text('Loading activity...',
                              style: theme.textTheme.bodySmall);
                        }
                        final data = snapshot.data!;
                        final listings = data['listingsCount'] ?? 0;
                        final interests = data['interestsCount'] ?? 0;
                        final conversations = data['conversationsCount'] ?? 0;
                        final earliestRaw = data['earliestActivityIso'];
                        DateTime? earliestDt;
                        if (earliestRaw is String) {
                          earliestDt = DateTime.tryParse(earliestRaw);
                        } else if (earliestRaw is int) {
                          earliestDt =
                              DateTime.fromMillisecondsSinceEpoch(earliestRaw);
                        } else if (earliestRaw is DateTime) {
                          earliestDt = earliestRaw;
                        }
                        final memberSince = earliestDt != null
                            ? DateFormat.yMMMd().format(earliestDt)
                            : 'Unknown';

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
                            Text('Member since $memberSince',
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: _openActivityLog,
                              child: Text('View activity log',
                                  style: theme.textTheme.labelLarge),
                            ),
                          ],
                        );
                      },
                    )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Editable form fields
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  _buildTextField(_fullNameController, 'Full Name',
                      isEnabled: _isEditing),
                  _buildTextField(_phoneNumberController, 'Phone Number',
                      isEnabled: _isEditing, keyboardType: TextInputType.phone),
                  _buildTextField(_districtController, 'District',
                      isEnabled: _isEditing),
                  if (_profileOwner.userType == kaawa.UserType.farmer)
                    ..._farmerFields,
                  const SizedBox(height: 16),
                  if (_isOwnProfile && _isEditing)
                    ElevatedButton(
                        onPressed: _saveChanges,
                        child: const Text('Save Changes')),
                  if (_isOwnProfile &&
                      _profileOwner.userType == kaawa.UserType.farmer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                          icon: const Icon(Icons.inventory),
                          label: const Text('Manage Coffee Stock'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ManageStockScreen(farmer: _profileOwner),
                              ),
                            );
                          }),
                    ),
                  if (_isOwnProfile &&
                      _profileOwner.userType != kaawa.UserType.admin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Message Admin'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContactAdminScreen(
                                  currentUser: widget.currentUser),
                            ),
                          );
                        },
                      ),
                    ),
                  if (!_isOwnProfile &&
                      _profileOwner.userType != kaawa.UserType.admin)
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
                      child: Text(_hasReviewed
                          ? 'Review already submitted'
                          : 'Write a Review'),
                    ),
                  const SizedBox(height: 12),
                  if (_profileOwner.userType != kaawa.UserType.admin)
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
                                    builder: (context) => ProfileScreen(
                                        currentUser: widget.currentUser,
                                        profileOwner: reviewer),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('View Reviews'),
                    ),
                  if (_isOwnProfile) ...[
                    const Divider(height: 40),
                    const Text('App Settings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(
                        Provider.of<ThemeNotifier>(context).themeMode ==
                                ThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                      title: const Text('Dark Mode'),
                      trailing: Switch(
                        value: Provider.of<ThemeNotifier>(context).themeMode ==
                            ThemeMode.dark,
                        onChanged: (val) {
                          Provider.of<ThemeNotifier>(context, listen: false)
                              .toggleTheme();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red)),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                  'Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Logout')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AuthService().logout();
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isEnabled = true,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !isEnabled,
          fillColor:
              !isEnabled ? Theme.of(context).colorScheme.surfaceVariant : null,
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
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
