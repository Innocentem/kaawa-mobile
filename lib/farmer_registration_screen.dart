
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';

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
      appBar: AppBar(
        title: const Text('Farmer Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your district';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _villageController,
                decoration: const InputDecoration(labelText: 'Village'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your village';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _coffeeTypeController,
                decoration: const InputDecoration(labelText: 'Coffee Type (e.g., Arabica, Robusta)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the coffee type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_currentPosition != null)
                Text(
                    'Current Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}'),
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Get Current Location'),
                onPressed: _getCurrentLocation,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
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
                      const SnackBar(content: Text('Registration successful!')),
                    );
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
