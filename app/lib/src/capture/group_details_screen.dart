import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/bottom_action_bar.dart';
import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../memories/memory_edit_screen.dart';
import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';
import 'discard_photo_dialog.dart';
import 'face_thumb.dart';
import 'photo_problems.dart';

/// Several faces from one photo: the place, meeting and details they
/// share. Saving makes one unnamed person per face, then returns to the
/// list filtered to the unnamed, so Fred can name them.
class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({
    super.key,
    required this.draft,
    required this.faces,
    required this.services,
  });

  final CaptureDraft draft;
  final List<PixelRect> faces;
  final AppServices services;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late String _place = widget.draft.place;
  late String _meeting = widget.draft.meeting;

  /// Each detail line with an id that keys its field.
  final _details = <({int id, String text})>[(id: 0, text: '')];
  int _nextId = 1;
  bool _saving = false;

  void _addLine() => setState(() => _details.add((id: _nextId++, text: '')));

  void _setLine(int id, String text) {
    final i = _details.indexWhere((d) => d.id == id);
    if (i >= 0) _details[i] = (id: id, text: text);
  }

  void _removeLine(int id) =>
      setState(() => _details.removeWhere((d) => d.id == id));

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final details = [
      for (final (i, d) in _details.indexed)
        Detail(
          id: '${now.microsecondsSinceEpoch.toRadixString(36)}-$i',
          text: d.text.trim(),
          at: now,
          type: DetailKind.fact,
        ),
    ];
    var saved = 0;
    String? problem;
    try {
      await widget.services.capture.saveGroup(
        widget.draft,
        widget.faces,
        place: _place,
        meeting: _meeting,
        details: details,
        onSaved: (_) => saved++,
      );
    } catch (e) {
      debugPrint('Group save stopped: $e');
      problem = saved == 0
          ? PhotoProblems.cannotSave
          : 'Saved $saved of ${widget.faces.length} people. The rest '
                "couldn't be saved. Check that your phone has free space.";
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (saved == 0 && problem != null) {
      // Nothing saved: stay, so Fred can try again.
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    if (problem != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(problem), duration: const Duration(seconds: 8)),
      );
    }
    // Back to the list, showing the people just saved.
    widget.services.listFilters.show([
      NameFilter(Memory.unknownName.toLowerCase()),
    ], note: 'Add their names while you remember.');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.faces.length;
    final dictation = widget.services.dictation;
    final text = Theme.of(context).textTheme;
    // Leaving mid-save would let the faces be saved a second time.
    return PopScope(canPop: !_saving, child: _page(count, dictation, text));
  }

  Widget _page(int count, Dictation dictation, TextTheme text) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group details'),
        actions: [
          HomeButton(
            enabled: !_saving,
            mayLeave: () => DiscardPhotoDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: RememberemTheme.gutter,
            vertical: 12,
          ),
          children: [
            DictatedTextField(
              ledger: true,
              label: 'Place',
              initialValue: _place,
              hint: 'unknown',
              dictation: dictation,
              onChanged: (v) => _place = v,
            ),
            const SizedBox(height: 8),
            DictatedTextField(
              ledger: true,
              label: 'Meeting',
              initialValue: _meeting,
              dictation: dictation,
              onChanged: (v) => _meeting = v,
            ),
            const SizedBox(height: 12),
            Text('Added to each of the $count people.'),
            const SizedBox(height: 4),
            Text(MemoryEditScreen.askedText, style: text.bodySmall),
            const SizedBox(height: 8),
            for (final (i, face) in widget.faces.indexed) _faceRow(i, face),
            const SizedBox(height: 16),
            Text('Details true of everyone here', style: text.titleSmall),
            Text('Each person may read these.', style: text.bodySmall),
            const SizedBox(height: 8),
            for (final (i, d) in _details.indexed)
              Padding(
                key: ValueKey(d.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DictatedTextField(
                        ledger: true,
                        label: 'Detail',
                        initialValue: d.text,
                        dictation: dictation,
                        onChanged: (v) => _setLine(d.id, v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove detail ${i + 1}',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removeLine(d.id),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add detail'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        end: FilledButton(
          style: BottomActionBar.goldStyle,
          onPressed: _saving ? null : _save,
          child: Text('Add $count people'),
        ),
      ),
    );
  }

  /// One face being added: its portrait and which one it is. At least
  /// 58 dp tall.
  Widget _faceRow(int i, PixelRect face) {
    final label = 'Face ${i + 1}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Row(
        children: [
          FaceThumb(photo: widget.draft.photo, face: face, label: label),
          const SizedBox(width: RememberemTheme.thumbGap),
          Expanded(child: ExcludeSemantics(child: Text(label))),
        ],
      ),
    );
  }
}
