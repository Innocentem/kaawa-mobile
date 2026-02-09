
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ManageStockScreen extends StatefulWidget {
  final User farmer;

  const ManageStockScreen({super.key, required this.farmer});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  late Future<List<CoffeeStock>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _stockFuture = _getCoffeeStock();
  }

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    return await DatabaseHelper.instance.getCoffeeStock(widget.farmer.id!);
  }

  void _showStockDialog({CoffeeStock? stock}) {
    showDialog(
      context: context,
      builder: (context) {
        return _StockDialog(farmerId: widget.farmer.id!, stock: stock);
      },
    ).then((_) {
      setState(() {
        _stockFuture = _getCoffeeStock();
      });
    });
  }

  Future<void> _toggleSoldStatus(CoffeeStock stock) async {
    final newStock = CoffeeStock(
      id: stock.id,
      farmerId: stock.farmerId,
      coffeeType: stock.coffeeType,
      quantity: stock.quantity,
      pricePerKg: stock.pricePerKg,
      coffeePicturePath: stock.coffeePicturePath,
      isSold: !stock.isSold,
    );
    await DatabaseHelper.instance.updateCoffeeStock(newStock);
    setState(() {
      _stockFuture = _getCoffeeStock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Coffee Stock'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Use the pencil icon to edit a listing, and the checkmark icon to mark it as sold.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CoffeeStock>>(
              future: _stockFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading stock.'));
                } else {
                  final stockItems = snapshot.data ?? [];
                  return stockItems.isEmpty
                      ? const Center(child: Text('You have no coffee stock yet.'))
                      : ListView.builder(
                          itemCount: stockItems.length,
                          itemBuilder: (context, index) {
                            final stock = stockItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: ListTile(
                                leading: stock.coffeePicturePath != null
                                    ? Image.file(File(stock.coffeePicturePath!))
                                    : const Icon(Icons.image, size: 40),
                                title: Text(stock.coffeeType),
                                subtitle: Text('${stock.quantity} Kgs at UGX ${stock.pricePerKg}/Kg'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showStockDialog(stock: stock),
                                    ),
                                    IconButton(
                                      icon: Icon(stock.isSold ? Icons.undo : Icons.check),
                                      onPressed: () => _toggleSoldStatus(stock),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStockDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  final int farmerId;
  final CoffeeStock? stock;

  const _StockDialog({required this.farmerId, this.stock});

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _coffeeTypeController;
  late TextEditingController _quantityController;
  late TextEditingController _pricePerKgController;
  String? _coffeePicturePath;

  @override
  void initState() {
    super.initState();
    _coffeeTypeController = TextEditingController(text: widget.stock?.coffeeType);
    _quantityController = TextEditingController(text: widget.stock?.quantity.toString());
    _pricePerKgController = TextEditingController(text: widget.stock?.pricePerKg.toString());
    _coffeePicturePath = widget.stock?.coffeePicturePath;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      setState(() {
        _coffeePicturePath = savedImage.path;
      });
    }
  }

  Future<void> _saveStock() async {
    if (_formKey.currentState!.validate()) {
      final newStock = CoffeeStock(
        id: widget.stock?.id,
        farmerId: widget.farmerId,
        coffeeType: _coffeeTypeController.text,
        quantity: double.parse(_quantityController.text),
        pricePerKg: double.parse(_pricePerKgController.text),
        coffeePicturePath: _coffeePicturePath,
      );

      if (widget.stock == null) {
        await DatabaseHelper.instance.insertCoffeeStock(newStock);
      } else {
        await DatabaseHelper.instance.updateCoffeeStock(newStock);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stock == null ? 'Add Coffee Stock' : 'Edit Coffee Stock'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _coffeeTypeController,
              decoration: const InputDecoration(labelText: 'Coffee Type'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the coffee type';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity (in Kgs)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the quantity';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _pricePerKgController,
              decoration: const InputDecoration(labelText: 'Price per Kg (in UGX)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the price per Kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildImagePicker(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveStock,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coffee Picture', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_coffeePicturePath != null)
          Image.file(File(_coffeePicturePath!), height: 150),
        TextButton.icon(
          icon: const Icon(Icons.image),
          label: Text(_coffeePicturePath == null ? 'Select Image' : 'Change Image'),
          onPressed: () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }
}
