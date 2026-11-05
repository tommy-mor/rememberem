import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/brand_logo.dart';
import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
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

  Widget _link(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    IconData trailing = Icons.open_in_new_rounded,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: Icon(trailing, size: 20),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const gutter = RememberemTheme.gutter;
    return Scaffold(
      appBar: AppBar(title: const Text('About'), actions: const [HomeButton()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(height: 48),
                const SizedBox(height: 12),
                Text(
                  'Rememberem was created by Eric Jorgensen.',
                  style: text.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Suggestions are welcome!', style: text.bodyLarge),
              ],
            ),
          ),
          _link(
            context,
            icon: Icons.public_rounded,
            title: 'ericjorgensen.com',
            onTap: () => _open(context, website),
          ),
          _link(
            context,
            icon: Icons.bug_report_rounded,
            title: 'Suggest an idea or report a problem',
            subtitle: 'github.com/nebosite/rememberem/issues',
            onTap: () => _open(context, issues),
          ),
          _link(
            context,
            icon: Icons.mail_rounded,
            title: 'Privacy questions',
            subtitle: email,
            onTap: () => _open(context, mail),
          ),
          const SectionHeader(title: 'Your data'),
          for (final paragraph in dataText)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: Text(paragraph, style: text.bodyMedium),
            ),
          const SizedBox(height: 8),
          _link(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy policy',
            onTap: () => _open(context, privacy),
          ),
          _link(
            context,
            icon: Icons.description_rounded,
            title: 'Licences',
            trailing: Icons.chevron_right_rounded,
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
