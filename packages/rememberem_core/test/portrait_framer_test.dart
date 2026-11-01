import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  const framer = PortraitFramer();

  test('frames head and shoulders around a centred face', () {
    final crop = framer.frame(const PixelRect(400, 300, 200, 240), 1000, 1500);

    expect(crop, const PixelRect(240, 180, 520, 650));
  });

  test('slides the crop inside the photo when the face is near an edge', () {
    final crop = framer.frame(const PixelRect(0, 0, 200, 240), 1000, 1500);

    expect(crop, const PixelRect(0, 0, 520, 650));
  });

  test('shrinks to fit, keeping a 4:5 portrait, when the face fills the photo',
      () {
    final crop = framer.frame(const PixelRect(50, 50, 300, 300), 400, 400);

    expect(crop, const PixelRect(40, 0, 320, 400));
  });
}
