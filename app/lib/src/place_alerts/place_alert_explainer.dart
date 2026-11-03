import 'package:flutter/material.dart';

/// What place notifications watch and who sees it, shown before Android
/// asks for location "all the time".
class PlaceAlertExplainer {
  const PlaceAlertExplainer._();

  static const title = 'Notice when you arrive';

  static const text =
      'When you arrive at a place where you have met people, Rememberem can '
      'remind you who they are.\n\n'
      'To notice you arriving, Rememberem uses your location in the '
      'background, even when the app is closed. Android\'s location service '
      'on your phone checks your places; Rememberem sends nothing anywhere.\n\n'
      "The notice shows the place name, never anyone's name. With a screen "
      'lock set, a locked phone shows only a general line.\n\n'
      'Android will ask you to allow notifications and location '
      '"All the time".';

  /// True if Fred chose to go ahead.
  static Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(title),
          content: const SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}
