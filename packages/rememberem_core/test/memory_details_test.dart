import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 11, 1, 10);

  Map<String, dynamic> legacyJson({Object? detailItems}) => {
        'id': 'p1',
        'photo': 'p1.jpg',
        'capturedAt': capturedAt.toIso8601String(),
        'location': null,
        'fields': {'name': 'Alex', 'details': 'Likes hiking'},
        if (detailItems != null) 'detailItems': detailItems,
      };

  test('a legacy details string loads as one detail timed at capture', () {
    final first = Memory.fromJson(legacyJson());
    final second = Memory.fromJson(legacyJson());

    final detail = first.details.single;
    expect(detail.text, 'Likes hiking');
    expect(detail.id, 'p1-legacy');
    expect(detail.at.isAtSameMomentAs(capturedAt), isTrue);
    expect(first.details, second.details);
    expect(first.fields, {'name': 'Alex'});
  });

  test('detailItems wins over the legacy key, even when empty', () {
    final both = Memory.fromJson(legacyJson(detailItems: [
      {'id': 'd1', 'text': 'From Seattle', 'at': '2026-11-01T10:05:00.000Z'},
    ]));
    final emptyList = Memory.fromJson(legacyJson(detailItems: []));

    expect(both.details.map((d) => d.text), ['From Seattle']);
    expect(emptyList.details, isEmpty);
  });

  test('saving a migrated record drops the legacy key', () {
    final migrated =
        Memory.fromJson(legacyJson()).withField('name', 'Alex Davis');

    final json = jsonDecode(jsonEncode(migrated)) as Map<String, dynamic>;

    expect((json['fields'] as Map).containsKey('details'), isFalse);
    expect((json['detailItems'] as List).single['text'], 'Likes hiking');
  });

  test('copyWith changes only what it is given, and keeps UTC', () {
    final detail = Detail(id: 'a', text: 'Tall', at: DateTime.utc(2026, 1, 1));

    final retexted = detail.copyWith(text: 'Very tall');
    final redated = detail.copyWith(at: DateTime(2020, 5, 6, 7, 8));

    expect(retexted.at, detail.at);
    expect(redated.text, 'Tall');
    expect(redated.id, 'a');
    expect(redated.at.isUtc, isTrue);
    expect(redated.at.isAtSameMomentAs(DateTime(2020, 5, 6, 7, 8)), isTrue);
  });

  test('details round-trip through the repository in order, in UTC',
      () async {
    final temp = await Directory.systemTemp.createTemp('rememberem_details_');
    addTearDown(() => temp.delete(recursive: true));
    final repository = JsonFileMemoryRepository(temp);
    final memory = await repository.add(photoJpeg: [1], capturedAt: capturedAt);
    final details = [
      Detail(id: 'a', text: 'One', at: DateTime.utc(2026, 11, 1, 10, 1)),
      Detail(id: 'b', text: 'Two', at: DateTime(2026, 11, 1, 3, 2)),
      Detail(id: 'c', text: 'Three', at: DateTime.utc(2026, 11, 1, 10, 3)),
    ];

    await repository.save(memory.withDetails(details));

    final loaded = (await repository.all()).single;
    expect(loaded.details, details);
    final raw = jsonDecode(
        await File('${temp.path}/${memory.id}.json').readAsString()) as Map;
    expect(
      (raw['detailItems'] as List).map((d) => d['at'] as String),
      everyElement(endsWith('Z')),
    );
  });
}
