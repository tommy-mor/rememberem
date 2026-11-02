import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../memories/memory_edit_screen.dart';
import 'face_picker_screen.dart';
import 'photo_picker.dart';

/// Full-screen camera. Taking a photo saves a cropped portrait and moves on
/// to the notes for that person; a photo of several people first asks whom
/// to remember.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.services,
    required this.routeObserver,
  });

  final AppServices services;

  /// For the Filter List a group photo ends on.
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _camera;
  Future<GeoPoint?>? _location;
  String? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } on Exception catch (e) {
      if (mounted) setState(() => _problem = 'Camera unavailable: $e');
    }
    // Asked after the camera so the two permission prompts don't collide.
    _location = widget.services.location.current();
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || _saving) return;
    await _save(() async {
      final capturedAt = DateTime.now();
      final shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();
      await File(shot.path).delete();
      return (bytes: bytes, capturedAt: capturedAt, location: await _location);
    });
  }

  /// A photo already on the phone: where and when come from the photo
  /// itself, never from where the phone is now (it may be an old photo).
  Future<void> _pickPhoto(PhotoPicker picker) async {
    if (_saving) return;
    await _save(() async {
      final photo = await picker.pick();
      if (photo == null) return null;
      final meta = PhotoMetadata.read(photo.bytes, now: DateTime.now());
      if (!photo.original && meta.location == null) _sayNoLocation(picker);
      return (
        bytes: photo.bytes,
        capturedAt: meta.takenAt ?? DateTime.now(),
        location: meta.location,
      );
    });
  }

  /// No location came, perhaps because the phone held it back; say how to
  /// allow it, without claiming it did. Shown
  /// on the app's messenger, so it stays up on the person's page.
  void _sayNoLocation(PhotoPicker picker) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No location came with this photo. If it should have one, '
          'allowing Rememberem photo access in Settings may help.',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => picker.openSettings().ignore(),
        ),
      ),
    );
  }

  /// Saves the photo [source] gives (null: nothing chosen) and moves on to
  /// the notes for that person, or to choosing faces if it has several.
  Future<void> _save(
    Future<({List<int> bytes, DateTime capturedAt, GeoPoint? location})?>
    Function()
    source,
  ) async {
    setState(() => _saving = true);
    try {
      final photo = await source();
      if (photo == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final settings = widget.services.settings.value;
      final capture = widget.services.capture;
      final draft = await capture.prepare(
        photo.bytes,
        capturedAt: photo.capturedAt,
        location: photo.location,
        placeFinder: settings.placeFinder,
        meetingFinder: settings.meetingFinder,
      );
      if (draft.faces.length > 1) {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            // Still the camera's job: the shortcut and reminders leave it be.
            settings: const RouteSettings(name: AppRoutes.capture),
            builder: (_) => FacePickerScreen(
              draft: draft,
              services: widget.services,
              routeObserver: widget.routeObserver,
            ),
          ),
        );
        return;
      }
      final memory = await capture.saveOne(draft, face: draft.largestFace);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              MemoryEditScreen(memory: memory, services: widget.services),
        ),
      );
    } catch (e) {
      // Any failure, Error included, must give the shutter back.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final picker = widget.services.photoPicker;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Meet someone'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null)
            Center(child: CameraPreview(camera))
          else
            Center(
              child: _problem == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _problem!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Balances the gallery button so the shutter stays centred.
                    const SizedBox(width: 72),
                    FloatingActionButton.large(
                      heroTag: 'shutter',
                      tooltip: 'Take photo',
                      onPressed: camera == null || _saving ? null : _takePhoto,
                      child: const Icon(Icons.camera_alt),
                    ),
                    SizedBox(
                      width: 72,
                      child: Center(
                        child: picker == null
                            ? null
                            : FloatingActionButton.small(
                                heroTag: 'gallery',
                                tooltip: 'Choose a photo from the phone',
                                onPressed: _saving
                                    ? null
                                    : () => _pickPhoto(picker),
                                child: const Icon(Icons.photo_library),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_saving)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  'Framing the photo…',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
