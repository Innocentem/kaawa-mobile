import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A small reusable shimmer skeleton for lists/grids/page loaders.
/// Usage:
/// - ShimmerSkeleton.rect(height: 120, width: double.infinity)
/// - ShimmerSkeleton.list(count: 6, axis: Axis.vertical)
class ShimmerSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerSkeleton.rect({Key? key, this.width, this.height, this.borderRadius = const BorderRadius.all(Radius.circular(8))}) : super(key: key);

  const ShimmerSkeleton._internal({Key? key, this.width, this.height, this.borderRadius = const BorderRadius.all(Radius.circular(8))}) : super(key: key);

  static Widget list({required int count, Axis axis = Axis.vertical, double spacing = 12.0}) {
    return SingleChildScrollView(
      scrollDirection: axis,
      child: Wrap(
        direction: axis,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(count, (i) => const ShimmerSkeleton._internal(width: 100.0, height: 100.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 16,
        decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
      ),
    );
  }
}
