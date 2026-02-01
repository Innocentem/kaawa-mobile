
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';

class ManageStockScreen extends StatefulWidget {
  final User farmer;

  const ManageStockScreen({super.key, required this.farmer});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _coffeeTypeController;
  late TextEditingController _quantityController;
  late TextEditingController _pricePerKgController;

  @override
  void initState() {
    super.initState();
    _coffeeTypeController = TextEditingController(text: widget.farmer.coffeeType);
    _quantityController = TextEditingController(text: widget.farmer.quantity?.toString());
    _pricePerKgController = TextEditingController(text: widget.farmer.pricePerKg?.toString());
  }

  Future<void> _saveStock() async {
    if (_formKey.currentState!.validate()) {
      final updatedFarmer = User(
        id: widget.farmer.id,
        fullName: widget.farmer.fullName,
        phoneNumber: widget.farmer.phoneNumber,
        password: widget.farmer.password,
        district: widget.farmer.district,
        userType: widget.farmer.userType,
        profilePicturePath: widget.farmer.profilePicturePath,
        latitude: widget.farmer.latitude,
        longitude: widget.farmer.longitude,
        village: widget.farmer.village,
        coffeeType: _coffeeTypeController.text,
        quantity: double.tryParse(_quantityController.text),
        pricePerKg: double.tryParse(_pricePerKgController.text),
        coffeePicturePath: widget.farmer.coffeePicturePath,
      );

      await DatabaseHelper.instance.updateUser(updatedFarmer);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully!')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Coffee Stock'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _coffeeTypeController,
                decoration: const InputDecoration(
                  labelText: 'Coffee Type (e.g., Arabica, Robusta)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the coffee type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (in Kgs)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pricePerKgController,
                decoration: const InputDecoration(
                  labelText: 'Price per Kg (in UGX)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the price per Kg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStock,
                child: const Text('Save Stock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
