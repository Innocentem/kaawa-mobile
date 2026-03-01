import 'package:flutter/material.dart';

/// A compact loader that fits inside buttons and small UI regions.
/// Uses theme-based colors and a smaller stroke width for consistency.
class CompactLoader extends StatelessWidget {
  final double size; // diameter
  final Color? color;
  final double strokeWidth;
  final String? semanticsLabel;

  const CompactLoader({Key? key, this.size = 18.0, this.color, this.strokeWidth = 2.0, this.semanticsLabel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onPrimary;
    final label = semanticsLabel ?? 'Loading';
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Semantics(
          label: label,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(c),
          ),
        ),
      ),
    );
  }
}
