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
  final String? heroTag;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.filePath,
    this.imageUrl,
    this.size,
    this.fit = BoxFit.cover,
    this.fallbackAsset = 'assets/images/avatar.jpg',
    this.heroTag,
    this.onTap,
  });

  Widget _buildNetworkImage(String url, ThemeData theme) {
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (context, url) {
        final base = theme.colorScheme.surface.withValues(alpha: 0.6);
        final highlight = theme.colorScheme.surface.withValues(alpha: 0.85);
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
              width: size, height: size, color: theme.colorScheme.surface),
        );
      },
      errorWidget: (context, url, error) {
        debugPrint('AppAvatar: Failed to load image from URL: $url. Error: $error');
        return Image.asset(fallbackAsset, width: size, height: size, fit: fit);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;

    try {
      final hasFilePath = filePath != null && filePath!.isNotEmpty;
      final hasImageUrl = imageUrl != null && imageUrl!.isNotEmpty;

      if (hasFilePath) {
        final isUrl =
            filePath!.startsWith('http') || filePath!.startsWith('https');
        if (isUrl) {
          content = _buildNetworkImage(filePath!, theme);
        } else {
          final cleanPath = filePath!.startsWith('file://')
              ? filePath!.replaceFirst('file://', '')
              : filePath!;
          final file = File(cleanPath);
          if (file.existsSync()) {
            content = Image.file(file, width: size, height: size, fit: fit);
          } else if (hasImageUrl &&
              (imageUrl!.startsWith('http') || imageUrl!.startsWith('https'))) {
            content = _buildNetworkImage(imageUrl!, theme);
          } else {
            content =
                Image.asset(fallbackAsset, width: size, height: size, fit: fit);
          }
        }
      } else if (hasImageUrl) {
        if (imageUrl!.startsWith('http') || imageUrl!.startsWith('https')) {
          content = _buildNetworkImage(imageUrl!, theme);
        } else {
          final cleanPath = imageUrl!.startsWith('file://')
              ? imageUrl!.replaceFirst('file://', '')
              : imageUrl!;
          final file = File(cleanPath);
          if (file.existsSync()) {
            content = Image.file(file, width: size, height: size, fit: fit);
          } else {
            content =
                Image.asset(fallbackAsset, width: size, height: size, fit: fit);
          }
        }
      } else {
        content =
            Image.asset(fallbackAsset, width: size, height: size, fit: fit);
      }
    } catch (_) {
      content = Image.asset(fallbackAsset, width: size, height: size, fit: fit);
    }

    Widget avatar = size != null
        ? SizedBox(width: size, height: size, child: ClipOval(child: content))
        : ClipOval(child: SizedBox.expand(child: content));

    if (heroTag != null) {
      avatar = Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: avatar,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
