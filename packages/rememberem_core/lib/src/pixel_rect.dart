/// An axis-aligned rectangle in image pixel coordinates.
class PixelRect {
  const PixelRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get area => width * height;

  @override
  bool operator ==(Object other) =>
      other is PixelRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PixelRect($left, $top, ${width}x$height)';
}
