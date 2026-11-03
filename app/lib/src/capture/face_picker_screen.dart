import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../memories/memory_edit_screen.dart';
import 'face_box.dart';
import 'group_details_screen.dart';
import 'photo_problems.dart';

/// A photo with several faces: Fred chooses whom to remember. One face is
/// saved as a person and opens their page; several go on to the details
/// they share. Nothing is saved until then.
class FacePickerScreen extends StatefulWidget {
  const FacePickerScreen({
    super.key,
    required this.draft,
    required this.services,
    required this.routeObserver,
  });

  final CaptureDraft draft;
  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<FacePickerScreen> createState() => _FacePickerScreenState();
}

class _FacePickerScreenState extends State<FacePickerScreen> {
  /// Indexes into the draft's faces.
  final _chosen = <int>{};
  bool _saving = false;

  List<PixelRect> get _faces => widget.draft.faces;

  void _toggle(int i) => setState(() {
    if (!_chosen.remove(i)) _chosen.add(i);
  });

  void _chooseAll() => setState(
    () => _chosen.addAll([for (var i = 0; i < _faces.length; i++) i]),
  );

  Future<void> _next() async {
    if (_chosen.isEmpty || _saving) return;
    final faces = [
      for (var i = 0; i < _faces.length; i++)
        if (_chosen.contains(i)) _faces[i],
    ];
    final navigator = Navigator.of(context);
    if (faces.length > 1) {
      // Held while the group page is open, so a double tap pushes it once.
      setState(() => _saving = true);
      await navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.capture),
          builder: (_) => GroupDetailsScreen(
            draft: widget.draft,
            faces: faces,
            services: widget.services,
            routeObserver: widget.routeObserver,
          ),
        ),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final memory = await widget.services.capture.saveOne(
        widget.draft,
        face: faces.single,
      );
      if (!mounted) return;
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MemoryEditScreen(
            memory: memory,
            services: widget.services,
            justMet: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not save photo: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(PhotoProblems.cannotSave)));
    }
  }

  /// Back would lose the photo, so ask first.
  Future<void> _confirmDiscard() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this photo?'),
        content: const Text('No one in it has been saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep choosing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = _chosen.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose faces'),
          actions: [
            Tooltip(
              message: 'Choose all faces',
              child: TextButton(
                onPressed: _saving ? null : _chooseAll,
                child: const Text('All'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Tap each face to remember. Choose only people who are '
                  'happy to be remembered.',
                ),
              ),
              Expanded(child: Center(child: _photo())),
            ],
          ),
        ),
        // Here, not in the body, so a message never covers it.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: count == 0 || _saving ? null : _next,
              child: Text(count <= 1 ? 'Add 1 person' : 'Add $count people'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    final photo = widget.draft.photo;
    return AspectRatio(
      aspectRatio: photo.width / photo.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / photo.width;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                photo.jpeg,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black),
              ),
              for (final (i, face) in _faces.indexed) _faceBox(i, face, scale),
            ],
          );
        },
      ),
    );
  }

  /// The box drawn at the face's size, but tappable over at least
  /// [_minTarget] square, centred on it: faces in a group are small.
  Widget _faceBox(int i, PixelRect face, double scale) {
    final width = face.width * scale;
    final height = face.height * scale;
    final targetWidth = max(width, _minTarget);
    final targetHeight = max(height, _minTarget);
    return Positioned(
      left: face.left * scale - (targetWidth - width) / 2,
      top: face.top * scale - (targetHeight - height) / 2,
      width: targetWidth,
      height: targetHeight,
      child: FaceBox(
        label: 'Face ${i + 1}',
        chosen: _chosen.contains(i),
        faceSize: Size(width, height),
        onTap: () => _toggle(i),
      ),
    );
  }

  static const _minTarget = 48.0;
}
