import 'dart:math';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Detail tag(
  String id,
  String? label, {
  String text = '',
  String? place,
  DateTime? on,
}) =>
    Detail(
      id: id,
      text: text,
      at: DateTime.utc(2026),
      type: DetailKind.tag,
      label: label,
      place: place,
      eventDate: on,
    );

Memory person(String id, List<Detail> details, {bool trashed = false}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      fields: {'name': id},
      details: details,
      trashedAt: trashed ? DateTime.utc(2026) : null,
    );

void main() {
  test('a tag round-trips with its type, place and date', () {
    final t = tag(
      't',
      'book club',
      text: 'Hosts in June',
      place: 'Library',
      on: DateTime(2026, 3, 3),
    );
    final back = Detail.fromJson(t.toJson());
    expect(back, t);
    expect(back.kind, DetailKind.tag);
    expect(t.toJson()['type'], 'tag');
  });

  test('a tag without a type or words is empty, so it is never saved', () {
    expect(tag('t', null, place: 'Library').isEmpty, isTrue);
    expect(tag('t', '  ', on: DateTime(2026)).isEmpty, isTrue);
    // Words Fred wrote are kept until he picks a type.
    expect(tag('t', null, text: 'Hosts').isEmpty, isFalse);
    expect(tag('t', 'book club').isEmpty, isFalse);
    // Other kinds still count any data.
    expect(
      Detail(id: 'f', text: 'Tall', at: DateTime.utc(2026)).isEmpty,
      isFalse,
    );
  });

  test('an unknown type reads as a fact', () {
    final json = tag('t', 'book club').toJson()..['type'] = 'sticker';
    expect(Detail.fromJson(json).kind, DetailKind.fact);
  });

  test('the date can be cleared; other parts are kept', () {
    final t = tag('t', 'club', place: 'Library', on: DateTime(2026, 3, 3));
    final cleared = t.copyWith(eventDate: () => null);
    expect(cleared.eventDate, isNull);
    expect(cleared.place, 'Library');
    expect(t.copyWith(text: 'x').eventDate, DateTime(2026, 3, 3));
  });

  test('tag types come only from tags in use, trash included', () {
    final people = [
      person('a', [tag('1', 'Book club'), tag('2', 'relatives')]),
      person('b', [tag('3', 'book club '), tag('4', '  ')]),
      person('c', [tag('5', 'Choir')], trashed: true),
      person('d', [
        Detail(
          id: '6',
          text: '',
          at: DateTime.utc(2026),
          type: DetailKind.anniversary,
          label: 'Wedding',
        ),
      ]),
    ];
    expect(DetailTypeCatalog.labels(DetailKind.tag, people), [
      'Book club',
      'relatives',
      'Choir',
    ]);
    expect(DetailTypeCatalog.labels(DetailKind.tag, []), isEmpty);
  });

  test('a tag reads as its type, place and date, the parts it has', () {
    String full(Detail d) => DetailPrompt(d, (_) => null).full;
    expect(
      full(
        tag(
          't',
          'book club',
          text: 'Hosts in June',
          place: 'Library',
          on: DateTime(2026, 3, 3),
        ),
      ),
      'Book club, Library, 3 Mar 2026: Hosts in June',
    );
    expect(full(tag('t', 'relatives')), 'Relatives');
    expect(full(tag('t', null, text: 'Odd one')), 'Odd one');
    expect(
      DetailPrompt.tagParts(tag('t', 'club', on: DateTime(2026, 1, 2))),
      ['Club', '2 Jan 2026'],
    );
  });

  test('tags are never practice questions', () {
    final people = [
      for (final id in ['a', 'b', 'c', 'd'])
        person(id, [tag('$id-t', 'book club', text: 'Reads a lot')]),
    ];
    expect(
      DetailQuizPlanner(Random(1), () => DateTime.utc(2026)).canPlay(people),
      isFalse,
    );
  });

  test('the Tag filter matches the tag, ignoring case and space', () {
    final ann = person('a', [tag('1', 'Book Club')]);
    final bo = person('b', [
      Detail(id: '2', text: 'book club', at: DateTime.utc(2026)),
      // Another kind's type with the same words is not a tag.
      Detail(
        id: '3',
        text: '',
        at: DateTime.utc(2026),
        type: DetailKind.relationship,
        label: 'Book club',
      ),
    ]);
    expect(const TagFilter(' book club').matches(ann), isTrue);
    expect(const TagFilter('book club').matches(bo), isFalse);
    expect(const TagFilter('choir').matches(ann), isFalse);
    expect(const TagFilter().isBlank, isTrue);
    expect(const TagFilter('  ').matches(bo), isTrue);
  });
}
