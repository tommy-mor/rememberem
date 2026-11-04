import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// The photo just taken, full screen, before anything is done with it:
/// "Use photo" (the big button, under the thumb) or "Retake".
class PhotoCheck extends StatelessWidget {
  const PhotoCheck({
    super.key,
    required this.jpeg,
    required this.onUse,
    required this.onRetake,
  });

  final Uint8List jpeg;
  final VoidCallback onUse;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Image.memory(
              jpeg,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: onRetake,
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      autofocus: true,
                      // Gold, like the shutter: it stands out on black
                      // whatever the theme colour.
                      style: FilledButton.styleFrom(
                        backgroundColor: RememberemTheme.gold,
                        foregroundColor: RememberemTheme.deepNavy,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: onUse,
                      child: const Text('Use photo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
