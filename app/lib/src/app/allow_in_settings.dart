import 'package:flutter/material.dart';

import 'system_settings.dart';

/// The one message for a permission Fred has turned off: what is missing,
/// and a Settings button to allow it.
class AllowInSettings {
  const AllowInSettings._();

  static SnackBar snackBar(
    String message, {
    SystemSettings settings = const SystemSettings(),
  }) => SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 8),
    action: SnackBarAction(
      label: 'Settings',
      onPressed: () => settings.open().ignore(),
    ),
  );
}
