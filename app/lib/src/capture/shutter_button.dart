import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// The camera's shutter: 76 dp of gold with a 3 dp white ring and a deep
/// navy camera icon. Dimmed and inert when [onPressed] is null.
class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const size = 76.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: 'Take photo',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Take photo',
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: RememberemTheme.gold,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 3),
            ),
            child: InkResponse(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 34,
                  color: RememberemTheme.deepNavy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
