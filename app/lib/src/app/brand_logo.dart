import 'package:flutter/material.dart';

/// The gold "Remember'em" wordmark, sized for an app bar. Screen readers
/// and tests still find the name.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40});

  /// The wordmark's height; its width follows (3.5 : 1).
  final double height;

  static const asset = 'assets/branding/logo_text_small.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rememberem',
      header: true,
      child: ExcludeSemantics(
        child: Image.asset(
          asset,
          height: height,
          // A fixed size, so it can be tapped before the image has loaded.
          width: height * 3.5,
          fit: BoxFit.contain,
          // A missing asset (as in some tests) falls back to the name.
          errorBuilder: (_, _, _) => const Text('Rememberem'),
        ),
      ),
    );
  }
}
