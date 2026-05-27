import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/interested_buyers_screen.dart';
import 'package:kaawa/widgets/listing_image.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/shimmer_skeleton.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageStockScreen extends StatefulWidget {
  final kaawa.User farmer;

  const ManageStockScreen({super.key, required this.farmer});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  late Stream<List<CoffeeStock>> _stockStream;
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
        color: theme.colorScheme.error.withValues(alpha: 0.9),
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
    _stockStream = _supabaseService.getCoffeeStockStreamByFarmer(widget.farmer.id!);
  }

  final SupabaseService _supabaseService = SupabaseService.instance;

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    return await _supabaseService.getCoffeeStockByFarmer(widget.farmer.id!);
  }

  void _showStockDialog({CoffeeStock? stock}) {
    showDialog(
      context: context,
      builder: (context) {
        return _StockDialog(farmerId: widget.farmer.id!, stock: stock);
      },
    );
  }

  Future<void> _toggleSoldStatus(CoffeeStock stock) async {
    final newStock = CoffeeStock(
      id: stock.id,
      farmerId: stock.farmerId,
      coffeeType: stock.coffeeType,
      quantity: stock.quantity,
      quantityRemaining: !stock.isSold ? 0 : stock.quantity,
      pricePerKg: stock.pricePerKg,
      coffeePicturePath: stock.coffeePicturePath,
      description: stock.description,
      isSold: !stock.isSold,
    );
    await SupabaseService.instance.updateCoffeeStock(newStock);
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.9),
              elevation: 0,
              foregroundColor: theme.colorScheme.onPrimary,
              iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
              actionsIconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
              title: const Text(
                'Manage Stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Your Listings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Edit a listing or mark it sold. Tap group to see interested buyers.',
                  child: Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CoffeeStock>>(
              stream: _stockStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ShimmerSkeleton.rect(height: 80, borderRadius: BorderRadius.circular(12)),
                    ),
                  );
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: stockItems.length,
                          itemBuilder: (context, index) {
                            final stock = stockItems[index];
                            final firstImage = _parseImages(stock.coffeePicturePath).first;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                tileColor: stock.isSold ? theme.colorScheme.error.withValues(alpha: 0.08) : null,
                                leading: firstImage != null
                                    ? SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Hero(
                                            tag: 'stock_manage_${stock.id}',
                                            child: ListingImage(path: firstImage, fit: BoxFit.cover),
                                          ),
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
                                      future: SupabaseService.instance.getInterestCountForStock(stock.id!),
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
                                                  builder: (context) => InterestedBuyersScreen(currentUser: widget.farmer, stock: stock),
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
  final String farmerId;
  final CoffeeStock? stock;

  const _StockDialog({required this.farmerId, this.stock});

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantityController;
  late TextEditingController _quantityRemainingController;
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
    _quantityRemainingController = TextEditingController(
      text: (widget.stock?.quantityRemaining ?? widget.stock?.quantity)?.toString()
    );
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
    _quantityController.dispose();
    _quantityRemainingController.dispose();
    _pricePerKgController.dispose();
    _descriptionController.dispose();
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

      String? finalImagePath = _coffeePicturePath;
      bool uploadFailed = false;
      if (_coffeePicturePath != null) {
        final paths = _coffeePicturePath!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        final uploadedUrls = <String>[];

        for (final p in paths) {
          if (p.startsWith('/') || p.startsWith('file:')) {
            final cleanPath = p.startsWith('file://') ? p.replaceFirst('file://', '') : p;
            final file = File(cleanPath);
            if (await file.exists()) {
              final publicUrl = await SupabaseService.instance.uploadImage(
                'kaawa-media',
                'stock/${widget.farmerId}',
                file,
              );
              if (publicUrl != null) {
                uploadedUrls.add(publicUrl);
              } else {
                uploadFailed = true;
                break;
              }
            } else {
              uploadFailed = true;
              break;
            }
          } else {
            uploadedUrls.add(p);
          }
        }
        
        if (uploadFailed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not upload one or more images. Please try again.')),
            );
          }
          return;
        }
        finalImagePath = uploadedUrls.join(',');
      }

      final newStock = CoffeeStock(
        id: widget.stock?.id,
        farmerId: widget.farmerId,
        coffeeType: coffeeType,
        quantity: double.parse(_quantityController.text),
        quantityRemaining: double.parse(_quantityRemainingController.text),
        pricePerKg: double.parse(_pricePerKgController.text),
        coffeePicturePath: finalImagePath,
        description: _descriptionController.text,
      );

      // Cleanup orphaned images from Supabase storage
      if (widget.stock != null && widget.stock!.coffeePicturePath != null) {
        final oldPaths = widget.stock!.coffeePicturePath!.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final newPaths = finalImagePath?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ?? [];

        for (final oldPath in oldPaths) {
          // If the old URL is a Supabase public URL and it's no longer in our list, delete it.
          if (oldPath.contains('supabase.co/storage/v1/object/public/') && !newPaths.contains(oldPath)) {
            await SupabaseService.instance.deleteImage('kaawa-media', oldPath);
          }
        }
      }

      if (widget.stock == null) {
        await SupabaseService.instance.insertCoffeeStock(newStock);
      } else {
        await SupabaseService.instance.updateCoffeeStock(newStock);
      }

      if (mounted) Navigator.pop(context);
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please select the coffee type' : null,
                      ),
                      if (_selectedCoffeeType == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _otherCoffeeTypeController,
                          decoration: InputDecoration(
                            labelText: 'Other Coffee Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (_selectedCoffeeType == 'Other' && (value == null || value.trim().isEmpty)) {
                              return 'Please specify the coffee type';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Original Total Quantity (in Kgs)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the total quantity';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityRemainingController,
                        decoration: InputDecoration(
                          labelText: 'Quantity Remaining (in Kgs)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: 'Update this as you sell offline',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter remaining quantity';
                          }
                          final remaining = double.tryParse(value);
                          if (remaining == null) {
                            return 'Please enter a valid number';
                          }
                          final total = double.tryParse(_quantityController.text);
                          if (total != null && remaining > total) {
                            return 'Remaining cannot exceed total';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pricePerKgController,
                        decoration: InputDecoration(
                          labelText: 'Price per Kg (in UGX)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the price per Kg';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
    final theme = Theme.of(context);
    final hasImages = _coffeePicturePath != null && _coffeePicturePath!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Coffee Pictures', style: TextStyle(fontWeight: FontWeight.bold)),
            if (hasImages)
              TextButton.icon(
                onPressed: () => setState(() => _coffeePicturePath = null),
                icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                label: const Text('Clear All', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasImages)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListingCarousel(images: _parseImages(_coffeePicturePath), fit: BoxFit.cover),
            ),
          )
        else
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 32, color: theme.hintColor),
                  const SizedBox(height: 4),
                  Text('No images selected', style: TextStyle(color: theme.hintColor)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_a_photo),
            label: Text(hasImages ? 'Add More' : 'Select Images'),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }
}
