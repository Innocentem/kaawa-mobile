import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/write_review_screen.dart';
import 'package:kaawa_mobile/view_reviews_screen.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'My Profile' : widget.profileOwner.fullName),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: Icon(_isEditing ? Icons.cancel : Icons.edit),
              onPressed: _toggleEditing,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              Center(
                child: Stack(
                  children: [
                    AppAvatar(
                      filePath: _profilePicturePath,
                      imageUrl: _profilePicturePath,
                      size: 100,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(_fullNameController, 'Full Name', isEnabled: _isEditing),
              _buildTextField(_phoneNumberController, 'Phone Number', isEnabled: _isEditing, keyboardType: TextInputType.phone),
              _buildTextField(_districtController, 'District', isEnabled: _isEditing),
              if (widget.profileOwner.userType == UserType.farmer) ..._farmerFields,
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewReviewsScreen(reviewedUser: widget.profileOwner),
                    ),
                  );
                },
                child: const Text('View Reviews'),
              ),
            ],
          ),
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
}
