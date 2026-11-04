import 'package:flutter/material.dart';

/// The page Fred reads before place notices ask for location all the time:
/// what is used, when, what for, and where it stays. True to go on.
class PlaceNoticeConsent extends StatelessWidget {
  const PlaceNoticeConsent({super.key});

  static Future<bool> show(BuildContext context) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PlaceNoticeConsent(),
        ),
      ) ??
      false;

  static const paragraphs = [
    'Rememberem uses your location in the background, even when the app '
        'is closed or not in use, to notice when you arrive at a place where '
        'you have met people, and tells you who.',
    "Your phone's own location service watches the places you have named "
        '(on Android, through Google Play services). Rememberem never sends '
        'your location anywhere; it stays on this phone.',
    'On the next screen, choose "Allow all the time". You can turn place '
        'notices off in Settings whenever you like.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Place notices')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.location_on_outlined, size: 48),
            const SizedBox(height: 16),
            Text('Location in the background', style: text.titleLarge),
            const SizedBox(height: 16),
            for (final p in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p, style: text.bodyLarge),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No thanks'),
            ),
          ],
        ),
      ),
    );
  }
}
