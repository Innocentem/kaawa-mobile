import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// ListingImage
/// - Displays a listing image from a local file (path) or a network URL (path).
/// - Falls back to assets/images/fallback.jpg when missing or on error.
/// - Provides a subtle loading placeholder using CachedNetworkImage's placeholder.
class ListingImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;

  const ListingImage({Key? key, this.path, this.fit = BoxFit.cover}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const fallback = 'assets/images/fallback.jpg';

    try {
      if (path != null && path!.isNotEmpty) {
        // local file
        if (path!.startsWith('/') || path!.startsWith('file://')) {
          final filePath = path!.startsWith('file://') ? path!.replaceFirst('file://', '') : path!;
          if (File(filePath).existsSync()) {
            return Image.file(File(filePath), fit: fit);
          }
        }

        // http(s)
        if (path!.startsWith('http') || path!.startsWith('https')) {
          return CachedNetworkImage(
            imageUrl: path!,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Image.asset(fallback, fit: fit),
          );
        }
      }
    } catch (_) {
      // ignored, fallback below
    }

    return Image.asset(fallback, fit: fit);
  }
}

// shimmer placeholder handled by the 'shimmer' package
