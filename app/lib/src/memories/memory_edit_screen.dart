import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';
import 'detail_list_editor.dart';
import 'memory_editor.dart';

/// The photo of a person with spoken-or-typed notes, saved as you go.
class MemoryEditScreen extends StatefulWidget {
  const MemoryEditScreen({
    super.key,
    required this.memory,
    required this.repository,
    required this.dictation,
  });

  final Memory memory;
  final MemoryRepository repository;
  final Dictation dictation;

  @override
  State<MemoryEditScreen> createState() => _MemoryEditScreenState();
}

class _MemoryEditScreenState extends State<MemoryEditScreen> {
  late final MemoryEditor _editor = MemoryEditor(
    widget.repository,
    widget.memory,
  );
  late final AppLifecycleListener _lifecycle;
  // Cached so pending snackbars (detail Undo) can be cleared on leaving.
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    // Saves straight away if the app is sent to the background.
    _lifecycle = AppLifecycleListener(onInactive: _editor.flush);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // Clearing during dispose upsets the messenger, so do it after the
    // frame. (Leaving via a shortcut skips the PopScope handler.)
    final messenger = _messenger;
    if (messenger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) messenger.clearSnackBars();
      });
    }
    _lifecycle.dispose();
    _editor.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Finish saving before leaving, so the list behind shows the latest.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        _messenger?.clearSnackBars();
        await _editor.flush();
        navigator.pop();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final memory = widget.memory;
    return Scaffold(
      appBar: AppBar(title: const Text('New person')),
      // Not a lazy ListView: fields scrolled out of view must keep their
      // text and any dictation in progress.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.repository.photoFile(memory),
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(height: 280, child: Icon(Icons.person)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _captionFor(memory),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final field in MemoryField.values) ...[
              const SizedBox(height: 16),
              DictatedTextField(
                label: field.label,
                initialValue: memory.field(field),
                dictation: widget.dictation,
                onChanged: (value) => _editor.update(field.key, value),
              ),
            ],
            const SizedBox(height: 16),
            DetailListEditor(
              details: _editor.memory.details,
              dictation: widget.dictation,
              onChanged: (id, text) =>
                  _edit(() => _editor.updateDetail(id, text)),
              onTimeChanged: (id, at) =>
                  _edit(() => _editor.setDetailTime(id, at)),
              onDelete: (id) => _edit(() => _editor.deleteDetail(id)),
              onRestore: (detail, index) =>
                  _edit(() => _editor.restoreDetail(detail, index)),
            ),
            const SizedBox(height: 16),
            Text(
              'Saved automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Applies a detail change and rebuilds so time captions stay current.
  void _edit(VoidCallback change) => setState(change);

  String _captionFor(Memory memory) {
    final when = MaterialLocalizations.of(context)
        .formatMediumDate(memory.capturedAt);
    final where = memory.location;
    return where == null
        ? when
        : '$when · ${where.latitude.toStringAsFixed(5)}, '
              '${where.longitude.toStringAsFixed(5)}';
  }
}
