
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/write_review_screen.dart';
import 'package:kaawa_mobile/view_reviews_screen.dart';
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

  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _districtController;
  late TextEditingController _villageController;
  late TextEditingController _coffeeTypeController;
  late TextEditingController _quantityController;
  late TextEditingController _pricePerKgController;
  late TextEditingController _coffeeTypeSoughtController;
  String? _profilePicturePath;
  String? _coffeePicturePath;

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
    _coffeeTypeController = TextEditingController(text: user.coffeeType);
    _quantityController = TextEditingController(text: user.quantity?.toString());
    _pricePerKgController = TextEditingController(text: user.pricePerKg?.toString());
    _coffeeTypeSoughtController = TextEditingController(text: user.coffeeTypeSought);
    _profilePicturePath = user.profilePicturePath;
    _coffeePicturePath = user.coffeePicturePath;
  }

  void _toggleEditing() {
    if (!_isOwnProfile) return;
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // If cancelling edit, reset the controllers to the original user data
        _initializeControllers(widget.profileOwner);
      }
    });
  }

  Future<void> _pickImage(ImageSource source, {bool isProfilePic = true}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      setState(() {
        if (isProfilePic) {
          _profilePicturePath = savedImage.path;
        } else {
          _coffeePicturePath = savedImage.path;
        }
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
      latitude: widget.profileOwner.latitude, // Latitude and longitude are not editable in this screen
      longitude: widget.profileOwner.longitude,
      village: _villageController.text,
      coffeeType: _coffeeTypeController.text.isEmpty ? null : _coffeeTypeController.text,
      quantity: double.tryParse(_quantityController.text),
      pricePerKg: double.tryParse(_pricePerKgController.text),
      coffeePicturePath: _coffeePicturePath,
      coffeeTypeSought: _coffeeTypeSoughtController.text.isEmpty ? null : _coffeeTypeSoughtController.text,
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
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profilePicturePath != null
                          ? FileImage(File(_profilePicturePath!))
                          : null,
                      child: _profilePicturePath == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () => _pickImage(ImageSource.gallery, isProfilePic: true),
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
              if (widget.profileOwner.userType == UserType.buyer)
                _buildTextField(_coffeeTypeSoughtController, 'Coffee Type Sought', isEnabled: _isEditing),
              const SizedBox(height: 24),
              if (_isOwnProfile && _isEditing)
                ElevatedButton(onPressed: _saveChanges, child: const Text('Save Changes')),
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

  Widget _buildTextField(TextEditingController controller, String label, {bool isEnabled = true, TextInputType keyboardType = TextInputType.text, bool isRequired = true}) {
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
          if (isRequired && (value == null || value.isEmpty)) {
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
      _buildTextField(_coffeeTypeController, 'Coffee Type', isEnabled: _isEditing, isRequired: false),
      _buildTextField(_quantityController, 'Quantity (in Kgs)', isEnabled: _isEditing, keyboardType: TextInputType.number, isRequired: false),
      _buildTextField(_pricePerKgController, 'Price per Kg (in UGX)', isEnabled: _isEditing, keyboardType: TextInputType.number, isRequired: false),
      if (_isEditing)
        _buildImagePicker(isProfilePic: false, label: 'Coffee Picture'),
      if (!_isEditing && _coffeePicturePath != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Image.file(File(_coffeePicturePath!)),
        ),
    ];
  }

  Widget _buildImagePicker({required bool isProfilePic, required String label}) {
    final imagePath = isProfilePic ? _profilePicturePath : _coffeePicturePath;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (imagePath != null)
            Image.file(File(imagePath), height: 150),
          TextButton.icon(
            icon: const Icon(Icons.image),
            label: Text(imagePath == null ? 'Select Image' : 'Change Image'),
            onPressed: () => _pickImage(ImageSource.gallery, isProfilePic: isProfilePic),
          ),
        ],
      ),
    );
  }
}
