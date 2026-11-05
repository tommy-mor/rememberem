import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/bottom_action_bar.dart';
import '../app/rememberem_theme.dart';

/// The photo just taken, full screen, before anything is done with it:
/// "Use photo" (gold, on the right) or "Retake".
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
          BottomActionBar(
            color: Colors.black,
            start: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(64, RememberemTheme.tapTarget),
              ),
              onPressed: onRetake,
              child: const Text('Retake'),
            ),
            end: FilledButton(
              autofocus: true,
              // Gold, like the shutter: it stands out on black whatever
              // the theme colour.
              style: BottomActionBar.goldStyle,
              onPressed: onUse,
              child: const Text('Use photo'),
            ),
          ),
        ],
      ),
    );
  }
}
