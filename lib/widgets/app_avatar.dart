import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// AppAvatar
/// - Displays an avatar from a local file (filePath) or a network URL (imageUrl).
/// - If neither is available it falls back to the provided asset (defaults to 'assets/images/avatar.jpg').
/// - If [size] is provided the avatar is square of that size; otherwise it expands to fill the parent.
class AppAvatar extends StatelessWidget {
  final String? filePath;
  final String? imageUrl;
  final double? size;
  final BoxFit fit;
  final String fallbackAsset;

  const AppAvatar({
    Key? key,
    this.filePath,
    this.imageUrl,
    this.size,
    this.fit = BoxFit.cover,
    this.fallbackAsset = 'assets/images/avatar.jpg',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content;

    try {
      if (filePath != null && File(filePath!).existsSync()) {
        content = Image.file(File(filePath!), width: size, height: size, fit: fit);
      } else if (imageUrl != null && imageUrl!.isNotEmpty && (imageUrl!.startsWith('http') || imageUrl!.startsWith('https'))) {
        content = CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 250),
          // shimmer placeholder while loading
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(width: size, height: size, color: Colors.white),
          ),
          // fallback if network fails
          errorWidget: (context, url, error) => Image.asset(fallbackAsset, width: size, height: size, fit: fit),
        );
      } else {
        content = Image.asset(fallbackAsset, width: size, height: size, fit: fit);
      }
    } catch (_) {
      content = Image.asset(fallbackAsset, width: size, height: size, fit: fit);
    }

    // If a size was provided wrap in a fixed box; otherwise let it expand to parent's constraints.
    final avatar = size != null
        ? SizedBox(width: size, height: size, child: ClipOval(child: content))
        : ClipOval(child: SizedBox.expand(child: content));

    return avatar;
  }
}

// shimmer provided by the 'shimmer' package now
