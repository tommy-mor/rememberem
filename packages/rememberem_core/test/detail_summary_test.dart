import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 3, 3, 10);
  String? nameOf(String id) => id == 'ann' ? 'Ann Lee' : null;
  Detail d(
    DetailKind kind, {
    String text = '',
    String? label,
    String? place,
    String? targetId,
    DateTime? eventDate,
  }) =>
      Detail(
        id: 'x',
        text: text,
        at: at,
        type: kind,
        label: label,
        place: place,
        targetId: targetId,
        eventDate: eventDate,
      );

  test('each kind reads data first, then the description', () {
    expect(
      DetailSummary.lineFor(
        d(DetailKind.relationship,
            label: 'brother', targetId: 'ann', text: 'helps at the cafe'),
        nameOf,
      ),
      'Brother: Ann Lee - helps at the cafe',
    );
    expect(
      DetailSummary.lineFor(
        d(DetailKind.anniversary,
            label: 'wedding',
            eventDate: DateTime(2010, 6, 3),
            text: 'at the lake'),
        nameOf,
      ),
      'Wedding: 3 Jun 2010 - at the lake',
    );
    expect(
      DetailSummary.lineFor(
        d(DetailKind.happening, place: 'Park', text: 'ran'),
        nameOf,
      ),
      '3 Mar 2026 · Park - ran',
    );
    expect(
      DetailSummary.lineFor(
        d(DetailKind.tag, label: 'relatives', place: 'Park', text: 'x'),
        nameOf,
      ),
      'Relatives · Park - x',
    );
    expect(
      DetailSummary.lineFor(d(DetailKind.fact, text: 'Loves jazz'), nameOf),
      'Loves jazz',
    );
  });

  test('no text leaves just the parts; a removed person says so', () {
    expect(
      DetailSummary.lineFor(
        d(DetailKind.relationship, label: 'boss', targetId: 'gone'),
        nameOf,
      ),
      'Boss: someone removed',
    );
    expect(DetailSummary.lineFor(d(DetailKind.fact), nameOf), '');
  });

  test('the kind heads only facts, happenings and tags', () {
    expect(DetailSummary.kindHead(d(DetailKind.fact)), 'Fact · ');
    expect(DetailSummary.kindHead(d(DetailKind.happening)), 'Happening · ');
    expect(DetailSummary.kindHead(d(DetailKind.tag)), 'Tag · ');
    expect(DetailSummary.kindHead(d(DetailKind.relationship)), '');
    expect(DetailSummary.kindHead(d(DetailKind.anniversary)), '');
  });

  test('kinds have plural headings', () {
    expect(DetailKind.values.map((k) => k.plural), [
      'Facts',
      'Happenings',
      'Relationships',
      'Anniversaries',
      'Tags',
    ]);
  });
}
