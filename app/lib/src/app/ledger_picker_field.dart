import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A ledger field that opens a picker instead of taking typing: an overline
/// [label] over the chosen [value], or the faint [hint] while there is
/// none. With [onClear] a clear button ends it. At least 48 dp tall.
class LedgerPickerField extends StatelessWidget {
  const LedgerPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.helper,
    this.onClear,
    this.clearTooltip,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? hint;
  final String? helper;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clear = onClear;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: RememberemTheme.ledgerDecoration(
          theme,
          label: label,
          hint: hint,
          suffix: clear == null
              ? null
              : IconButton(
                  tooltip: clearTooltip,
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: clear,
                ),
        ).copyWith(helperText: helper),
        child: Text(value),
      ),
    );
  }
}
