import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// Chooses a photo already on the phone: a 48 dp rounded square, white at
/// 15 %, over the camera. Dimmed and inert when [onPressed] is null.
class GalleryButton extends StatelessWidget {
  const GalleryButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const _tooltip = 'Choose a photo from the phone';

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: _tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: _tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox.square(
                dimension: RememberemTheme.tapTarget,
                child: Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
