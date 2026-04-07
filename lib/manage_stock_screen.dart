import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/interested_buyers_screen.dart';
import 'package:kaawa/widgets/listing_image.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/compact_loader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageStockScreen extends StatefulWidget {
  final User farmer;

  const ManageStockScreen({super.key, required this.farmer});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  late Future<List<CoffeeStock>> _stockFuture;
  final LayerLink _editLink = LayerLink();
  final GlobalKey _editKey = GlobalKey();
  bool _guideScheduled = false;

  List<String?> _parseImages(String? pathField) {
    if (pathField == null || pathField.trim().isEmpty) return [null];
    final parts = pathField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [null];
    return parts;
  }

  Widget _buildSoldBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'SOLD',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

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

  Future<void> _scheduleEditGuide() async {
    if (_guideScheduled) return;
    _guideScheduled = true;

    final prefs = await SharedPreferences.getInstance();
    final key = 'guide_manage_stock_v1_${widget.farmer.id}';
    if (prefs.getBool(key) == true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showCoachMark(
        link: _editLink,
        targetKey: _editKey,
        title: 'Edit or mark sold',
        message: 'Use the pencil to edit a listing or the check to mark it sold.',
      );
      await prefs.setBool(key, true);
    });
  }

  Future<void> _showCoachMark({
    required LayerLink link,
    required GlobalKey targetKey,
    required String title,
    required String message,
  }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final screenHeight = overlayBox?.size.height ?? MediaQuery.of(context).size.height;
    final targetOffset = (renderBox != null && overlayBox != null)
        ? renderBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : Offset.zero;
    final targetHeight = renderBox?.size.height ?? 0.0;
    const tooltipHeightEstimate = 140.0;
    final spaceAbove = targetOffset.dy;
    final spaceBelow = screenHeight - (targetOffset.dy + targetHeight);
    final showAbove = spaceAbove >= tooltipHeightEstimate || spaceAbove > spaceBelow;

    final completer = Completer<void>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          onTap: () {
            entry.remove();
            completer.complete();
          },
          child: Material(
            color: Colors.black54,
            child: SafeArea(
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: link,
                    targetAnchor: showAbove ? Alignment.topCenter : Alignment.bottomCenter,
                    followerAnchor: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                    offset: showAbove ? const Offset(0, -8) : const Offset(0, 8),
                    showWhenUnlinked: false,
                    child: Material(
                      color: Colors.transparent,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Card(
                          color: theme.colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(message, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 8),
                                Text('Tap anywhere to continue', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    await completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actionsIconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        title: const Text('Manage Stock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Your Listings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Edit a listing or mark it sold. Tap group to see interested buyers.',
                  child: Icon(Icons.info_outline, size: 18, color: IconTheme.of(context).color ?? theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CoffeeStock>>(
              future: _stockFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(width: double.infinity, height: 200, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading listings'))));
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading stock.'));
                } else {
                  final stockItems = snapshot.data ?? [];
                  if (stockItems.isNotEmpty) {
                    _scheduleEditGuide();
                  }
                  return stockItems.isEmpty
                      ? const Center(child: Text('No stock yet.'))
                      : ListView.builder(
                          itemCount: stockItems.length,
                          itemBuilder: (context, index) {
                            final stock = stockItems[index];
                            final firstImage = _parseImages(stock.coffeePicturePath).first;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: ListTile(
                                tileColor: stock.isSold ? theme.colorScheme.error.withAlpha((0.08 * 255).round()) : null,
                                leading: firstImage != null
                                    ? SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: ListingImage(path: firstImage, fit: BoxFit.cover),
                                        ),
                                      )
                                    : const Icon(Icons.image, size: 40),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(stock.coffeeType, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    if (stock.isSold) ...[
                                      const SizedBox(width: 6),
                                      _buildSoldBadge(theme),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${stock.quantity} kg • UGX ${stock.pricePerKg}/kg', maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (stock.isSold)
                                      Text('SOLD', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FutureBuilder<int>(
                                      future: DatabaseHelper.instance.getInterestCountForStock(stock.id!),
                                      builder: (context, snapshotCount) {
                                        final count = snapshotCount.data ?? 0;
                                        return Tooltip(
                                          message: 'Interested buyers',
                                          child: IconButton(
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
                                                      decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
                                                      child: Text('$count', style: TextStyle(color: theme.colorScheme.onError, fontSize: 10)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => InterestedBuyersScreen(farmer: widget.farmer, stock: stock),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    Tooltip(
                                      message: 'Edit listing',
                                      child: index == 0
                                          ? CompositedTransformTarget(
                                              link: _editLink,
                                              child: IconButton(
                                                key: _editKey,
                                                icon: const Icon(Icons.edit),
                                                onPressed: () => _showStockDialog(stock: stock),
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () => _showStockDialog(stock: stock),
                                            ),
                                    ),
                                    Tooltip(
                                      message: stock.isSold ? 'Mark as available' : 'Mark as sold',
                                      child: TextButton.icon(
                                        onPressed: () => _toggleSoldStatus(stock),
                                        icon: Icon(stock.isSold ? Icons.undo : Icons.check),
                                        label: Text(stock.isSold ? 'Mark available' : 'Mark sold'),
                                      ),
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
        tooltip: 'Add stock',
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
  late TextEditingController _quantityController;
  late TextEditingController _pricePerKgController;
  late TextEditingController _descriptionController;
  final TextEditingController _otherCoffeeTypeController = TextEditingController();
  String? _coffeePicturePath;
  String? _selectedCoffeeType;

  static const List<String> _coffeeTypes = [
    'Arabica',
    'Robusta',
    'Liberica',
    'Excelsa',
    'Cherry',
    'Green (raw)',
    'Dried',
    'Roasted',
    'Processed',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.stock?.quantity.toString());
    _pricePerKgController = TextEditingController(text: widget.stock?.pricePerKg.toString());
    _descriptionController = TextEditingController(text: widget.stock?.description ?? '');
    _coffeePicturePath = widget.stock?.coffeePicturePath;

    final initialType = widget.stock?.coffeeType?.trim();
    if (initialType != null && initialType.isNotEmpty) {
      if (_coffeeTypes.contains(initialType)) {
        _selectedCoffeeType = initialType;
      } else {
        _selectedCoffeeType = 'Other';
        _otherCoffeeTypeController.text = initialType;
      }
    }
  }

  @override
  void dispose() {
    _otherCoffeeTypeController.dispose();
    super.dispose();
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
      final coffeeType = _selectedCoffeeType == 'Other'
          ? _otherCoffeeTypeController.text.trim()
          : (_selectedCoffeeType ?? '');

      final newStock = CoffeeStock(
        id: widget.stock?.id,
        farmerId: widget.farmerId,
        coffeeType: coffeeType,
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
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.stock == null ? 'Add Coffee Stock' : 'Edit Coffee Stock',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCoffeeType,
                          items: _coffeeTypes
                              .map((type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCoffeeType = value;
                              if (value != 'Other') {
                                _otherCoffeeTypeController.clear();
                              }
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Coffee Type',
                            filled: true,
                            fillColor: theme.brightness == Brightness.light
                                ? theme.colorScheme.surfaceVariant.withAlpha(230)
                                : theme.colorScheme.surfaceVariant.withAlpha(120),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Please select the coffee type' : null,
                        ),
                        if (_selectedCoffeeType == 'Other')
                          TextFormField(
                            controller: _otherCoffeeTypeController,
                            decoration: const InputDecoration(labelText: 'Other Coffee Type'),
                            validator: (value) {
                              if (_selectedCoffeeType == 'Other' && (value == null || value.trim().isEmpty)) {
                                return 'Please specify the coffee type';
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
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveStock,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
