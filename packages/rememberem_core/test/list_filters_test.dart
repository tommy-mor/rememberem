import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(
  String id, {
  String name = '',
  DateTime? met,
  List<Detail> details = const [],
}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: met ?? DateTime(2026, 1, 1, 12),
      fields: {'name': name},
      details: details,
    );

Detail detail(
  String id,
  DetailKind kind, {
  String text = '',
  String? label,
  DateTime? at,
  DateTime? on,
}) =>
    Detail(
      id: id,
      text: text,
      at: at ?? DateTime(2020, 1, 1, 12),
      type: kind,
      label: label,
      eventDate: on,
    );

void main() {
  group('DateRangeFilter', () {
    final june = DateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 30));

    test('matches a photo taken in range', () {
      final p = person('a', met: DateTime(2026, 6, 15, 9));
      expect(june.matches(p), isTrue);
      expect(june.encountersIn(p).single.capturedAt, DateTime(2026, 6, 15, 9));
      expect(june.matches(person('b')), isFalse);
    });

    test('matches a happening, a tag date and an anniversary any year', () {
      final picnic = detail('h', DetailKind.happening,
          text: 'Picnic', at: DateTime(2026, 6, 10, 15));
      final club =
          detail('t', DetailKind.tag, label: 'club', on: DateTime(2026, 6, 20));
      final wedding = detail('w', DetailKind.anniversary,
          label: 'wedding', on: DateTime(2010, 6, 3));
      final tall =
          detail('f', DetailKind.fact, text: 'Tall', at: DateTime(2026, 6, 5));
      final p = person('a', details: [picnic, club, wedding, tall]);

      expect(june.matches(p), isTrue);
      expect(june.encountersIn(p), isEmpty);
      expect(june.detailsIn(p).map((d) => d.id), ['h', 't', 'w']);
    });

    test('an anniversary matches across a year end, not before it began', () {
      final eve = detail('w', DetailKind.anniversary,
          label: 'wedding', on: DateTime(2020, 12, 31));
      final p = person('a', details: [eve]);
      final newYear =
          DateRangeFilter(DateTime(2025, 12, 28), DateTime(2026, 1, 3));
      expect(newYear.detailsIn(p), [eve]);
      final before =
          DateRangeFilter(DateTime(2019, 12, 1), DateTime(2019, 12, 31));
      expect(before.matches(p), isFalse);
    });

    test('a blank range matches everyone and lists nothing', () {
      final p = person('a');
      expect(const DateRangeFilter().matches(p), isTrue);
      expect(const DateRangeFilter().detailsIn(p), isEmpty);
      expect(const DateRangeFilter().encountersIn(p), isEmpty);
    });
  });

  group('DetailsFilter', () {
    test('matches the description or the type, ignoring case', () {
      final boss = detail('r', DetailKind.relationship, label: 'Boss');
      final sings = detail('f', DetailKind.fact, text: 'She sings bass');
      final p = person('a', details: [boss, sings]);
      expect(const DetailsFilter('boss').detailsIn(p), [boss]);
      expect(const DetailsFilter(' SING ').detailsIn(p), [sings]);
      expect(const DetailsFilter('opera').matches(p), isFalse);
    });

    test('finds every place the text sits, for highlighting', () {
      expect(const DetailsFilter('ba').spans('Bass and banjo'), [
        (0, 2),
        (9, 11),
      ]);
      expect(const DetailsFilter('').spans('Bass'), isEmpty);
    });
  });

  group('PeopleOrder', () {
    final ann = person('ann', name: 'Ann Zed', met: DateTime(2026, 3, 1));
    final bob = person('bob', name: 'bob Young', met: DateTime(2026, 1, 1));
    final cy = person('cy', name: 'Cy Adams', met: DateTime(2026, 2, 1));
    final old = person('x', met: DateTime(2025, 1, 1));
    final recent = person('y', met: DateTime(2026, 4, 1));
    final all = [old, cy, recent, ann, bob];

    List<String> ids(PeopleOrder o) => o.apply(all).map((m) => m.id).toList();

    test('by date, newest first; unnamed people last', () {
      expect(ids(const PeopleOrder()), ['ann', 'cy', 'bob', 'y', 'x']);
      expect(ids(const PeopleOrder(PersonSort.date, true)),
          ['bob', 'cy', 'ann', 'x', 'y']);
    });

    test('by first or last name, ignoring case; unnamed still last', () {
      expect(ids(const PeopleOrder(PersonSort.firstName)),
          ['ann', 'bob', 'cy', 'y', 'x']);
      expect(ids(const PeopleOrder(PersonSort.lastName)),
          ['cy', 'bob', 'ann', 'y', 'x']);
      expect(ids(const PeopleOrder(PersonSort.lastName, true)),
          ['ann', 'bob', 'cy', 'y', 'x']);
    });

    test('equal names and dates mirror exactly when reversed', () {
      final same = [
        for (var i = 0; i < 20; i++)
          person('p$i', name: 'Alex', met: DateTime(2026)),
      ];
      for (final sort in PersonSort.values) {
        final forward = PeopleOrder(sort).apply(same);
        final back = PeopleOrder(sort, true).apply(same);
        expect(back.map((m) => m.id), forward.reversed.map((m) => m.id));
      }
    });

    test('choosing the same sort again reverses it; another starts forwards',
        () {
      const byFirst = PeopleOrder(PersonSort.firstName);
      expect(byFirst.choose(PersonSort.firstName),
          const PeopleOrder(PersonSort.firstName, true));
      expect(byFirst.choose(PersonSort.firstName).choose(PersonSort.date),
          const PeopleOrder());
    });
  });
}
