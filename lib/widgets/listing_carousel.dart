import 'package:flutter/material.dart';
import 'package:kaawa_mobile/widgets/listing_image.dart';

/// ListingCarousel
/// - Accepts a list of image paths (local file paths or http URLs).
/// - Falls back to asset fallback when an image is missing.
/// - Shows a PageView with simple dot indicators and allows tapping to forward to a provided onTap callback.
class ListingCarousel extends StatefulWidget {
  final List<String?> images;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const ListingCarousel({Key? key, required this.images, this.height, this.fit = BoxFit.cover, this.onTap}) : super(key: key);

  @override
  State<ListingCarousel> createState() => _ListingCarouselState();
}

class _ListingCarouselState extends State<ListingCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? [null] : widget.images;
    final height = widget.height ?? MediaQuery.of(context).size.width * 0.5;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final path = images[i];
              return GestureDetector(
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: ListingImage(path: path, fit: widget.fit),
                ),
              );
            },
          ),
          // Dots indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: active
                        ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
