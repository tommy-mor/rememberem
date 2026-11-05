import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/bottom_action_bar.dart';
import '../app/home_button.dart';
import 'crop_corners.dart';

/// Crops a photo to a 4:5 portrait: pinch and drag it in the frame, then
/// Crop pops with the framed part as JPEG bytes. Back pops with nothing.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.jpeg});

  final Uint8List jpeg;

  /// Width over height of the frame, as every portrait is.
  static const aspect = 4 / 5;

  /// The part of a [imageWidth] × [imageHeight] photo seen through a frame
  /// of [frame] size, where the photo is first fitted to cover the frame
  /// and then transformed by [matrix] (from an InteractiveViewer).
  static PixelRect visibleRect({
    required int imageWidth,
    required int imageHeight,
    required Size frame,
    required Matrix4 matrix,
  }) {
    final cover = math.max(
      frame.width / imageWidth,
      frame.height / imageHeight,
    );
    // Where the fitted photo sits in the frame before any pinch or drag.
    final dx = (frame.width - imageWidth * cover) / 2;
    final dy = (frame.height - imageHeight * cover) / 2;
    final inverse = Matrix4.inverted(matrix);
    Offset toImage(Offset frameOffset) {
      final child = MatrixUtils.transformPoint(inverse, frameOffset);
      return Offset((child.dx - dx) / cover, (child.dy - dy) / cover);
    }

    final topLeft = toImage(Offset.zero);
    final bottomRight = toImage(Offset(frame.width, frame.height));
    final left = topLeft.dx.round().clamp(0, imageWidth - 1);
    final top = topLeft.dy.round().clamp(0, imageHeight - 1);
    final right = bottomRight.dx.round().clamp(left + 1, imageWidth);
    final bottom = bottomRight.dy.round().clamp(top + 1, imageHeight);
    return PixelRect(left, top, right - left, bottom - top);
  }

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _transform = TransformationController();
  late final Future<Size> _imageSize = _decodeSize();
  Size _frame = Size.zero;
  bool _cropping = false;

  Future<Size> _decodeSize() async {
    final image = await decodeImageFromList(widget.jpeg);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_cropping || _frame.isEmpty) return;
    setState(() => _cropping = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final size = await _imageSize;
      final rect = CropScreen.visibleRect(
        imageWidth: size.width.round(),
        imageHeight: size.height.round(),
        frame: _frame,
        matrix: _transform.value,
      );
      final bytes = await PortraitCropper.cropInBackground(widget.jpeg, rect);
      if (mounted) navigator.pop(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cropping = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not crop this photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crop'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Done',
            icon: const Icon(Icons.check_rounded),
            onPressed: _cropping ? null : _done,
          ),
          const HomeButton(),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Use pinch to zoom in or out, then press Done',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Expanded(child: _frameArea()),
          BottomActionBar(
            start: TextButton(
              onPressed: _cropping ? null : _reset,
              child: const Text('Reset'),
            ),
            end: FilledButton(
              style: BottomActionBar.goldStyle,
              onPressed: _cropping ? null : _done,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  /// Back to the photo as first fitted.
  void _reset() => _transform.value = Matrix4.identity();

  Widget _frameArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: CropScreen.aspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _frame = constraints.biggest;
              return Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 6,
                        child: SizedBox.expand(
                          child: Image.memory(
                            widget.jpeg,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const CropCorners(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
