import 'package:flutter/material.dart';

import '../app/brand_logo.dart';
import 'link_opener.dart';

/// Who made Rememberem, and where to send ideas or report a problem.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.links});

  final LinkOpener links;

  static final website = Uri.parse('https://ericjorgensen.com');
  static final issues = Uri.parse(
    'https://github.com/nebosite/rememberem/issues',
  );

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
      appBar: AppBar(title: const Text('About')),
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
        ],
      ),
    );
  }
}
