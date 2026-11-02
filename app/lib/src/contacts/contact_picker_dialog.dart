import 'package:flutter/material.dart';

import 'contact_entry.dart';
import 'contact_matcher.dart';

/// Choose the contact to link: every contact A to Z, opened at the best
/// match for [personName] (highlighted), with a search box. Pops with the
/// chosen contact's key. The list lives only as long as the dialog.
class ContactPickerDialog extends StatefulWidget {
  const ContactPickerDialog({
    super.key,
    required this.entries,
    required this.personName,
  });

  final List<ContactEntry> entries;
  final String personName;

  static const itemExtent = 56.0;

  @override
  State<ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<ContactPickerDialog> {
  late final int _best = ContactMatcher.bestIndex(
    widget.entries,
    widget.personName,
  );
  late final _scroll = ScrollController(
    initialScrollOffset: _best < 0 ? 0 : _best * ContactPickerDialog.itemExtent,
  );
  String _filter = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<(int, ContactEntry)> get _shown {
    final filter = _filter.trim().toLowerCase();
    return [
      for (final (i, e) in widget.entries.indexed)
        if (filter.isEmpty || e.name.toLowerCase().contains(filter)) (i, e),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final highlight = Theme.of(context).colorScheme.secondaryContainer;
    return AlertDialog(
      title: const Text('Link to a contact'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search contacts',
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('No contacts found.'))
                  : ListView.builder(
                      controller: _scroll,
                      itemExtent: ContactPickerDialog.itemExtent,
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final (index, entry) = shown[i];
                        return ListTile(
                          tileColor: index == _best ? highlight : null,
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(entry.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
