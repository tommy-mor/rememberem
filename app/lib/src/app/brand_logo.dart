import 'package:flutter/material.dart';

/// The gold "Remember'em" wordmark, sized for an app bar. Screen readers
/// and tests still find the name.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  static const asset = 'assets/branding/logo_text_small.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rememberem',
      header: true,
      child: ExcludeSemantics(
        child: Image.asset(
          asset,
          height: 40,
          fit: BoxFit.contain,
          // A missing asset (as in some tests) falls back to the name.
          errorBuilder: (_, _, _) => const Text('Rememberem'),
        ),
      ),
    );
  }
}
