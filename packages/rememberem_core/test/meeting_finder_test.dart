import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  const finder = MeetingFinder();
  final now = DateTime.utc(2026, 11, 1, 12);

  Memory met(String place, String meeting, Duration before,
          {String id = 'p'}) =>
      Memory.captured(
        id: id,
        photoFileName: '$id.jpg',
        capturedAt: now.subtract(before),
        place: place,
        meeting: meeting,
      );

  test('the meeting closest in time wins, whatever the order', () {
    final standup =
        met('Cafe', 'Standup', const Duration(minutes: 90), id: 'a');
    final lunch = met('Cafe', 'Lunch', const Duration(minutes: 30), id: 'b');

    expect(finder.suggest('Cafe', now, [standup, lunch]), 'Lunch');
    expect(finder.suggest('Cafe', now, [lunch, standup]), 'Lunch');
  });

  test('exactly two hours counts; a minute more does not', () {
    expect(
      finder.suggest(
          'Cafe', now, [met('Cafe', 'Choir', const Duration(minutes: 120))]),
      'Choir',
    );
    expect(
      finder.suggest(
          'Cafe', now, [met('Cafe', 'Choir', const Duration(minutes: 121))]),
      '',
    );
  });

  test('an encounter dated after the new photo also counts', () {
    expect(
      finder.suggest(
          'Cafe', now, [met('Cafe', 'Later', const Duration(minutes: -30))]),
      'Later',
    );
  });

  test('equal gaps go to the newest encounter in either order', () {
    final before = met('Cafe', 'Before', const Duration(minutes: 30), id: 'a');
    final after = met('Cafe', 'After', const Duration(minutes: -30), id: 'b');

    expect(finder.suggest('Cafe', now, [before, after]), 'After');
    expect(finder.suggest('Cafe', now, [after, before]), 'After');
  });

  test('other places and blank meetings are ignored even when closest', () {
    final people = [
      met('Park', 'Picnic', const Duration(minutes: 1), id: 'a'),
      met('Cafe', '  ', const Duration(minutes: 2), id: 'b'),
      met('Cafe ', 'Book club', const Duration(minutes: 60), id: 'c'),
    ];

    expect(finder.suggest('Cafe', now, people), 'Book club');
  });

  test('a blank place never suggests a meeting', () {
    expect(finder.suggest(' ', now, [met('', 'Choir', Duration.zero)]), '');
  });

  test('every encounter counts, not only the newest', () {
    final memory = Memory(id: 'p', encounters: [
      Encounter(
          photoFileName: 'new.jpg',
          capturedAt: DateTime.utc(2027),
          place: 'Park',
          meeting: 'Picnic'),
      Encounter(
          photoFileName: 'old.jpg',
          capturedAt: now.subtract(const Duration(minutes: 10)),
          place: 'Cafe',
          meeting: 'Standup'),
    ]);

    expect(finder.suggest('Cafe', now, [memory]), 'Standup');
  });
}
