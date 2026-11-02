import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(String id, int points,
        [List<(String, int)> details = const []]) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      details: [
        for (final (i, (text, p)) in details.indexed)
          Detail(id: '$id-$i', text: text, at: DateTime.utc(2026), points: p),
      ],
    ).withScore(points, null);

void main() {
  test('faces count from five points up', () {
    final people = [person('a', 4), person('b', 5), person('c', 6)];

    expect(RememberedCount.of(people).faces, 2);
  });

  test('details count by their own points, blank ones never', () {
    final people = [
      person('a', 0, [('Tall', 5), ('Kind', 4), ('  ', 9)]),
      person('b', 5, [('Choir', 0)]),
    ];

    expect(RememberedCount.of(people), const RememberedCount(1, 1));
  });

  test('nobody, nothing; the input is untouched', () {
    final people = [person('a', 7)];

    expect(RememberedCount.of([]), const RememberedCount(0, 0));
    expect(RememberedCount.of([]).isNothing, isTrue);
    RememberedCount.of(people);
    expect(people.single.points, 7);
  });
}
