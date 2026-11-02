import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'contact_open_result.dart';
import 'contact_picker_dialog.dart';
import 'contacts_service.dart';

/// The person card's contact icon. Unlinked, a tap finds the contact to
/// link. Linked, a tap shows the contact on the phone and a long press
/// offers Re-assign or Remove link. Only the contact's key is kept.
class ContactLinkButton extends StatefulWidget {
  const ContactLinkButton({
    super.key,
    required this.memoryId,
    required this.initialKey,
    required this.personName,
    required this.contacts,
    required this.repository,
  });

  final String memoryId;
  final String? initialKey;

  /// The name as Fred has it now, to start the list at the best match.
  final String Function() personName;
  final ContactsService contacts;
  final MemoryRepository repository;

  @override
  State<ContactLinkButton> createState() => _ContactLinkButtonState();
}

class _ContactLinkButtonState extends State<ContactLinkButton> {
  late String? _key = widget.initialKey;

  /// Set while a contacts call is in flight; taps are ignored meanwhile.
  bool _busy = false;

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } on PlatformException catch (e) {
      // "busy": another call is already showing; nothing to say.
      if (e.code != 'busy') _say('Contacts are not available right now.');
    } catch (_) {
      _say('Contacts are not available right now.');
    } finally {
      _busy = false;
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _tap() => _guarded(() async {
    final key = _key;
    if (key == null) return _assign();
    switch (await widget.contacts.open(key)) {
      case ContactOpenResult.opened:
        break;
      case ContactOpenResult.notFound:
        _say(
          'Contact not found on this phone. Long-press to link another '
          'or remove the link.',
        );
      case ContactOpenResult.noApp:
        _say('There is no contacts app to show it.');
    }
  });

  void _longPress() => _guarded(() async {
    if (_key == null) return _assign();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Re-assign contact'),
              onTap: () => Navigator.of(context).pop('reassign'),
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Remove link'),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'reassign') await _assign();
    if (choice == 'remove') await _link(null);
  });

  /// Finds a contact: the list at the best match if Fred allows reading
  /// contacts, else the phone's own picker.
  Future<void> _assign() async {
    final contacts = widget.contacts;
    final String? key;
    if (await contacts.ensureAccess()) {
      final entries = await contacts.list();
      if (!mounted) return;
      key = await showDialog<String>(
        context: context,
        builder: (_) => ContactPickerDialog(
          entries: entries,
          personName: widget.personName(),
        ),
      );
    } else {
      key = await contacts.pickWithSystemPicker();
    }
    if (key != null) await _link(key);
  }

  /// Saves the link (or its removal); dropped if the card has closed.
  Future<void> _link(String? key) async {
    if (!mounted) return;
    await widget.repository.setContactKey(widget.memoryId, key);
    if (mounted) setState(() => _key = key);
  }

  @override
  Widget build(BuildContext context) {
    final linked = _key != null;
    return IconButton(
      tooltip: linked ? 'Open contact' : 'Link to a contact',
      icon: Icon(linked ? Icons.contact_page : Icons.contact_page_outlined),
      onPressed: _tap,
      onLongPress: _longPress,
    );
  }
}
