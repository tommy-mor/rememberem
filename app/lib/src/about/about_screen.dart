import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/brand_logo.dart';
import '../app/home_button.dart';
import '../places/place_notice_keeper.dart';
import '../reminders/reminder_coordinator.dart';
import 'debug_section.dart';
import 'link_opener.dart';

/// Who made Rememberem, where to send ideas or report a problem, and
/// where Fred's people are kept.
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    required this.links,
    this.reminders,
    this.placeNotices,
  });

  final LinkOpener links;

  /// For the debug controls, shown only in a debug build.
  final ReminderCoordinator? reminders;
  final PlaceNoticeKeeper? placeNotices;

  static final website = Uri.parse('https://ericjorgensen.com');
  static final issues = Uri.parse(
    'https://github.com/nebosite/rememberem/issues',
  );
  static final privacy = Uri.parse(
    'https://nebosite.github.io/rememberem/privacy.html',
  );
  static const email = 'rememberem@niftibits.com';
  static final mail = Uri(scheme: 'mailto', path: email);

  /// Where the people Fred saves are kept, and what can leave the phone.
  static const dataText = [
    "Photos and notes are kept in Rememberem's private storage on this "
        'phone. No account, no ads, and no analytics of our own.',
    'If your phone backs up to Google, Rememberem is included, so your '
        'people can come back on a new phone. Google keeps up to 25 MB for '
        'each app, roughly 200 people. To leave Rememberem out, turn off '
        "backup in your phone's Settings.",
    'The people you photograph are in that backup too. If someone asks '
        'where their photo is kept, tell them.',
    "Dictation uses your phone's on-device speech recogniser where it has "
        "one. Otherwise your phone's speech service may send the audio to "
        'be recognised.',
    'Street maps load from OpenStreetMap, which sees your internet address '
        'and the area shown. You can turn maps off in Settings.',
    'Place notices, if you turn them on, use your location in the '
        "background: your phone's own location service watches the places "
        'you have named, and Rememberem never sends your location anywhere.',
  ];

  Future<void> _open(BuildContext context, Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await links.open(url)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About'), actions: const [HomeButton()]),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: BrandLogo()),
          const SizedBox(height: 24),
          Text(
            'Rememberem was created by Eric Jorgensen.',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Suggestions are welcome!',
            style: text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('ericjorgensen.com'),
            onTap: () => _open(context, website),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Suggest an idea or report a problem'),
            subtitle: const Text('github.com/nebosite/rememberem/issues'),
            onTap: () => _open(context, issues),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Privacy questions'),
            subtitle: const Text(email),
            onTap: () => _open(context, mail),
          ),
          const SizedBox(height: 16),
          Text('Where your people are kept', style: text.titleMedium),
          for (final paragraph in dataText)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(paragraph, style: text.bodyMedium),
            ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => _open(context, privacy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licences'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Rememberem',
            ),
          ),
          if (kDebugMode)
            if (reminders case final reminders?)
              DebugSection(reminders: reminders, placeNotices: placeNotices),
        ],
      ),
    );
  }
}
