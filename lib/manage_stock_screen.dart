import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/interested_buyers_screen.dart';
import 'package:kaawa_mobile/widgets/listing_image.dart';
import 'package:kaawa_mobile/widgets/listing_carousel.dart';
import 'package:kaawa_mobile/widgets/shimmer_skeleton.dart';
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
      description: stock.description,
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
                  return Center(child: SizedBox(width: double.infinity, height: 200, child: ShimmerSkeleton.rect()));
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
                                    ? SizedBox(width: 40, height: 40, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: ListingImage(path: stock.coffeePicturePath, fit: BoxFit.cover)))
                                    : const Icon(Icons.image, size: 40),
                                title: Text(stock.coffeeType),
                                subtitle: Text('${stock.quantity} Kgs at UGX ${stock.pricePerKg}/Kg'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Interested buyers button with count badge
                                    FutureBuilder<int>(
                                      future: DatabaseHelper.instance.getInterestCountForStock(stock.id!),
                                      builder: (context, snapshotCount) {
                                        final count = snapshotCount.data ?? 0;
                                        return IconButton(
                                          icon: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(Icons.group),
                                              if (count > 0)
                                                Positioned(
                                                  right: -6,
                                                  top: -6,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          onPressed: () {
                                            // open the interested buyers screen for this stock
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => InterestedBuyersScreen(farmer: widget.farmer, stock: stock),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
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
  late TextEditingController _descriptionController;
  String? _coffeePicturePath;

  @override
  void initState() {
    super.initState();
    _coffeeTypeController = TextEditingController(text: widget.stock?.coffeeType);
    _quantityController = TextEditingController(text: widget.stock?.quantity.toString());
    _pricePerKgController = TextEditingController(text: widget.stock?.pricePerKg.toString());
    _descriptionController = TextEditingController(text: widget.stock?.description ?? '');
    _coffeePicturePath = widget.stock?.coffeePicturePath;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      // try multi-image first
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final savedPaths = <String>[];
        for (final pf in pickedFiles) {
          final fileName = p.basename(pf.path);
          final savedImage = await File(pf.path).copy('${appDir.path}/$fileName');
          savedPaths.add(savedImage.path);
        }
        // merge with existing if present
        final existing = _coffeePicturePath == null ? [] : _coffeePicturePath!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        final merged = [...existing, ...savedPaths];
        setState(() {
          _coffeePicturePath = merged.join(',');
        });
        return;
      }

      // fallback to single image picker if multi not supported / empty
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(pickedFile.path);
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

        final existing = _coffeePicturePath == null ? [] : _coffeePicturePath!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        existing.add(savedImage.path);

        setState(() {
          _coffeePicturePath = existing.join(',');
        });
      }
    } catch (e) {
      // ignore or show error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image(s): $e')));
    }
  }

  List<String?> _parseImages(String? pathField) {
    if (pathField == null || pathField.trim().isEmpty) return [null];
    final parts = pathField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [null];
    return parts;
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
        description: _descriptionController.text,
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
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
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
          SizedBox(
            height: 150,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ListingCarousel(images: _parseImages(_coffeePicturePath), fit: BoxFit.cover),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.image),
          label: Text(_coffeePicturePath == null ? 'Select Image' : 'Change Image'),
          onPressed: () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }
}
