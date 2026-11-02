import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../memories/memory_edit_screen.dart';

/// Full-screen camera. Taking a photo saves a cropped portrait and moves on
/// to the notes for that person.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.services});

  final AppServices services;

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
    setState(() => _saving = true);
    try {
      final capturedAt = DateTime.now();
      final shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();
      await File(shot.path).delete();
      final memory = await widget.services.capture.capture(
        bytes,
        capturedAt: capturedAt,
        location: await _location,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MemoryEditScreen(
            memory: memory,
            repository: widget.services.repository,
            dictation: widget.services.dictation,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Take photo',
        onPressed: camera == null || _saving ? null : _takePhoto,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
