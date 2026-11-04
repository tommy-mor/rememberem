import 'package:flutter/material.dart';

/// A group of settings in a box, its [title] on the border (as a detail's
/// kind sits on its field), on a slightly darker tint on light pages and a
/// slightly lighter one on dark pages.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
      child: InputDecorator(
        decoration: InputDecoration(
          // A heading for screen readers.
          label: Semantics(header: true, child: Text(title)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          // 30% larger than a title once the border shrinks a floating
          // label to 3/4, in the page's own text colour, which reads on
          // every background.
          floatingLabelStyle: base?.copyWith(
            fontSize: (base.fontSize ?? 16) * 1.3 / 0.75,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          filled: true,
          fillColor: Color.alphaBlend(
            scheme.onSurface.withAlpha(12),
            scheme.surface,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
