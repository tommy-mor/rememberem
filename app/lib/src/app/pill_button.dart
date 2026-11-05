import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A 30 dp pill with an optional icon, inside a 48 dp tap area. Outlined
/// in the theme colour, or [filled] with a tint of it. With [onPressed] it
/// is a button; without, it is only the look, for a menu button's child.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.filled = false,
    this.onPressed,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool filled;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: RememberemTheme.tapTarget,
        minHeight: RememberemTheme.tapTarget,
      ),
      child: Center(
        widthFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: filled ? scheme.primary.withValues(alpha: 0.10) : null,
            border: filled
                ? null
                : Border.all(color: scheme.primary.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: scheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
    if (onPressed == null) return pill;
    return Tooltip(
      message: tooltip ?? label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip ?? label,
        // The tap goes on this node: excluding the InkWell's own would
        // otherwise leave a screen reader nothing to activate.
        onTap: onPressed,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: pill,
        ),
      ),
    );
  }
}
