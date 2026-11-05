import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/allow_in_settings.dart';
import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../app/system_settings.dart';
import '../memories/memory_edit_screen.dart';
import 'face_picker_screen.dart';
import 'gallery_button.dart';
import 'photo_check.dart';
import 'photo_picker.dart';
import 'photo_problems.dart';
import 'shutter_button.dart';

/// A photo to keep, held until it is saved so a failure can try again.
typedef _Photo = ({List<int> bytes, DateTime capturedAt, GeoPoint? location});

/// Full-screen camera. A photo taken is shown first, to use or retake;
/// using it saves a cropped portrait and moves on to the notes for that
/// person, and a photo of several people first asks whom to remember.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _camera;
  Future<GeoPoint?>? _location;

  /// Why there is no camera, in Fred's words.
  String? _problem;

  /// The camera was refused, so Settings can help.
  bool _denied = false;
  bool _saving = false;

  /// The photo just taken, waiting for Use photo or Retake (its location
  /// is looked up on Use). Only in memory, so leaving the app with it
  /// showing uses it: a photo is never lost.
  ({List<int> bytes, DateTime capturedAt})? _review;

  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () {
      if (_review != null) _usePhoto();
    },
  );

  /// This screen's own messages, which go when it does: a Try again left
  /// on the next screen would act on a photo no longer here.
  final _messages = GlobalKey<ScaffoldMessengerState>();

  /// Set when the chosen photo came without its location, perhaps held
  /// back by the phone, so the next screen can say how to allow it.
  PhotoPicker? _noLocationFrom;

  @override
  void initState() {
    super.initState();
    _lifecycle; // created now, so it listens from the start
    _openCamera();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _problem = 'This device has no camera.');
      } else {
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
      }
    } catch (e) {
      // Error too: a camera that fails must still leave a way forward.
      debugPrint('Camera unavailable: $e');
      final denied = e is CameraException && e.code.startsWith('CameraAccess');
      if (mounted) {
        setState(() {
          _denied = denied;
          _problem = denied
              ? 'The camera is off for Rememberem.'
              : 'The camera could not be opened.';
        });
      }
    }
    _findLocation();
  }

  /// Asked after the camera so the two permission prompts don't collide.
  /// If location is off, Fred hears why the place is blank.
  void _findLocation() {
    final location = widget.services.location;
    _location = location.current().then((here) async {
      if (here == null && await location.denied() && mounted) {
        _messages.currentState?.showSnackBar(
          AllowInSettings.snackBar(
            'Location is off for Rememberem, so no place is saved.',
          ),
        );
      }
      return here;
    });
  }

  /// Takes a photo and shows it to check; nothing is saved yet.
  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || _saving || _review != null) return;
    setState(() => _saving = true);
    final ({List<int> bytes, DateTime capturedAt}) photo;
    try {
      final capturedAt = DateTime.now();
      final shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();
      await File(shot.path).delete();
      photo = (bytes: bytes, capturedAt: capturedAt);
      // The camera rests while the photo is checked.
      await camera.pausePreview().catchError((_) {});
    } catch (e) {
      debugPrint('Could not get the photo: $e');
      _failed("Couldn't get the photo. Please try again.");
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _review = photo;
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Photo taken. Use photo, or Retake.',
      Directionality.of(context),
    );
  }

  void _retake() {
    setState(() => _review = null);
    _camera?.resumePreview().catchError((_) {});
  }

  Future<void> _usePhoto() async {
    final review = _review;
    if (review == null || _saving) return;
    setState(() {
      _review = null;
      _saving = true;
    });
    final photo = (
      bytes: review.bytes,
      capturedAt: review.capturedAt,
      location: await _location,
    );
    // A failed save comes back to the check, so the photo is kept.
    final saved = await _save(photo, onFail: () => _review = review);
    if (!saved && mounted) _camera?.resumePreview().catchError((_) {});
  }

  /// A photo already on the phone: where and when come from the photo
  /// itself, never from where the phone is now (it may be an old photo).
  Future<void> _pickPhoto(PhotoPicker picker) async {
    if (_saving) return;
    await _take(() async {
      final photo = await picker.pick();
      if (photo == null) return null;
      final meta = PhotoMetadata.read(photo.bytes, now: DateTime.now());
      _noLocationFrom = !photo.original && meta.location == null
          ? picker
          : null;
      return (
        bytes: photo.bytes,
        capturedAt: meta.takenAt ?? DateTime.now(),
        location: meta.location,
      );
    });
  }

  /// Replaces the camera with [route]. If the chosen photo came without its
  /// location, says so on the app's messenger once [route] is showing, so
  /// the message stays up there.
  Future<void> _moveOn(Route<void> route) {
    final appMessages = ScaffoldMessenger.of(context);
    final picker = _noLocationFrom;
    _noLocationFrom = null;
    final moved = Navigator.of(context).pushReplacement(route);
    if (picker != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sayNoLocation(appMessages, picker),
      );
    }
    return moved;
  }

  /// No location came, perhaps because the phone held it back; say how to
  /// allow it, without claiming it did.
  static void _sayNoLocation(
    ScaffoldMessengerState appMessages,
    PhotoPicker picker,
  ) {
    appMessages.showSnackBar(
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

  /// Gets a photo from [source] (null: nothing chosen) and saves it.
  Future<void> _take(Future<_Photo?> Function() source) async {
    _noLocationFrom = null;
    setState(() => _saving = true);
    final _Photo? photo;
    try {
      photo = await source();
    } catch (e) {
      debugPrint('Could not get the photo: $e');
      _failed("Couldn't get the photo. Please try again.");
      return;
    }
    if (photo == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    await _save(photo);
  }

  /// Saves [photo] and moves on to the notes for that person, or to
  /// choosing faces if it has several; true if it did. On failure the
  /// photo is kept, so Fred can try again without taking it again: with
  /// [onFail], it goes back where it came from; else a Try again.
  Future<bool> _save(_Photo photo, {VoidCallback? onFail}) async {
    setState(() => _saving = true);
    try {
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
        if (!mounted) return true;
        await _moveOn(
          MaterialPageRoute<void>(
            // Still the camera's job: the shortcut and reminders leave it be.
            settings: const RouteSettings(name: AppRoutes.capture),
            builder: (_) =>
                FacePickerScreen(draft: draft, services: widget.services),
          ),
        );
        return true;
      }
      final memory = await capture.saveOne(draft, face: draft.largestFace);
      if (!mounted) return true;
      await _moveOn(
        MaterialPageRoute<void>(
          builder: (_) => MemoryEditScreen(
            memory: memory,
            services: widget.services,
            justMet: true,
          ),
        ),
      );
      return true;
    } catch (e) {
      // Any failure, Error included, must give the shutter back.
      debugPrint('Could not save photo: $e');
      if (onFail != null && mounted) {
        setState(onFail);
        _failed(PhotoProblems.cannotSave);
      } else {
        _failed(PhotoProblems.cannotSave, retry: () => _save(photo));
      }
      return false;
    }
  }

  void _failed(String message, {VoidCallback? retry}) {
    if (!mounted) return;
    setState(() => _saving = false);
    _messages.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        action: retry == null
            ? null
            : SnackBarAction(
                label: 'Try again',
                onPressed: () {
                  if (mounted && !_saving) retry();
                },
              ),
      ),
    );
  }

  /// No camera: say why, and offer the ways on.
  Widget _noCamera(String problem) {
    final picker = widget.services.photoPicker;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            problem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (_denied)
            FilledButton(
              onPressed: () => const SystemSettings().open().ignore(),
              child: const Text('Open settings'),
            ),
          if (picker != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _saving ? null : () => _pickPhoto(picker),
              child: const Text('Choose a photo instead'),
            ),
          ],
        ],
      ),
    );
  }

  /// The consent cue: one quiet line at the gutter, no extra step.
  Widget _askFirst() => const Padding(
    padding: EdgeInsets.fromLTRB(
      RememberemTheme.gutter,
      0,
      RememberemTheme.gutter,
      12,
    ),
    child: DecoratedBox(
      // Dark behind the words, so they read over any scene.
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'Ask first: "Mind if I take a photo so I remember your name?"',
          style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
        ),
      ),
    ),
  );

  /// Shutter in the middle, the gallery on the right, and an empty slot of
  /// the same width on the left so the shutter stays centred.
  Widget _shutterRow(CameraController? camera, PhotoPicker? picker) => Padding(
    padding: const EdgeInsets.fromLTRB(
      RememberemTheme.gutter,
      0,
      RememberemTheme.gutter,
      16,
    ),
    child: Row(
      children: [
        const SizedBox(width: RememberemTheme.tapTarget),
        Expanded(
          child: Center(
            child: ShutterButton(
              onPressed: camera == null || _saving ? null : _takePhoto,
            ),
          ),
        ),
        SizedBox(
          width: RememberemTheme.tapTarget,
          child: picker == null
              ? null
              : GalleryButton(
                  onPressed: _saving ? null : () => _pickPhoto(picker),
                ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final problem = _problem;
    final picker = widget.services.photoPicker;
    // Back while checking a photo is Retake, never leaving with it.
    return PopScope(
      canPop: _review == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _retake();
      },
      child: ScaffoldMessenger(
        key: _messages,
        child: _scaffold(camera, problem, picker),
      ),
    );
  }

  Widget _scaffold(
    CameraController? camera,
    String? problem,
    PhotoPicker? picker,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Meet someone'),
        actions: [HomeButton(enabled: !_saving && _review == null)],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null)
            Center(child: CameraPreview(camera))
          else
            Center(
              child: problem == null
                  ? const CircularProgressIndicator()
                  : _noCamera(problem),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            // Clear of the navigation bar and a notch on its side.
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (camera != null) _askFirst(),
                  _shutterRow(camera, picker),
                ],
              ),
            ),
          ),
          if (_review case final photo?)
            // Only the check's own buttons for a screen reader.
            BlockSemantics(
              child: PhotoCheck(
                // The camera's bytes, not a copy, so it decodes once.
                jpeg: photo.bytes is Uint8List
                    ? photo.bytes as Uint8List
                    : Uint8List.fromList(photo.bytes),
                onUse: _usePhoto,
                onRetake: _retake,
              ),
            ),
          if (_saving)
            const ColoredBox(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      minHeight: 3,
                      color: RememberemTheme.gold,
                      backgroundColor: Colors.transparent,
                    ),
                    Padding(
                      padding: EdgeInsets.all(RememberemTheme.gutter),
                      child: Text(
                        'Framing the photo…',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
