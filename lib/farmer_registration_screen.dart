
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/theme/app_colors.dart';
import 'package:kaawa_mobile/theme/app_typography.dart';

class FarmerRegistrationScreen extends StatefulWidget {
  const FarmerRegistrationScreen({super.key});

  @override
  State<FarmerRegistrationScreen> createState() => _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState extends State<FarmerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _districtController = TextEditingController();
  final _villageController = TextEditingController();
  final _coffeeTypeController = TextEditingController();
  final _passwordController = TextEditingController();
  Position? _currentPosition;

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Farmer Registration'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Coffee plant icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    size: 60,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Join as a Coffee Farmer',
                style: AppTypography.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect with buyers and grow your business',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District',
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your district';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                decoration: const InputDecoration(
                  labelText: 'Village',
                  prefixIcon: Icon(Icons.home),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your village';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coffeeTypeController,
                decoration: const InputDecoration(
                  labelText: 'Coffee Type (e.g., Arabica, Robusta)',
                  prefixIcon: Icon(Icons.coffee),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the coffee type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_currentPosition != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGreen),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Location captured: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentPosition != null) const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    'Get Current Location',
                    style: AppTypography.button,
                  ),
                  onPressed: _getCurrentLocation,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final hashedPassword = sha256.convert(utf8.encode(_passwordController.text)).toString();
                      final fcmToken = await FirebaseMessaging.instance.getToken();
                      final newUser = User(
                        fullName: _fullNameController.text,
                        phoneNumber: _phoneNumberController.text,
                        password: hashedPassword,
                        district: _districtController.text,
                        userType: UserType.farmer,
                        fcmToken: fcmToken,
                        village: _villageController.text,
                        coffeeType: _coffeeTypeController.text,
                        latitude: _currentPosition?.latitude,
                        longitude: _currentPosition?.longitude,
                      );
                      await DatabaseHelper.instance.insertUser(newUser);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registration successful!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                  child: Text(
                    'Register',
                    style: AppTypography.button,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
