import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(String id, String name,
        {bool detail = false, bool trashed = false}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      fields: {'name': name},
      details: [
        if (detail) Detail(id: '$id-d', text: 'Tall', at: DateTime.utc(2026))
      ],
      trashedAt: trashed ? DateTime.utc(2026) : null,
    );

void main() {
  group('ReminderSettings', () {
    test('off by default at 19:00', () {
      const off = ReminderSettings.off();
      expect([off.enabled, off.hour, off.minute], [false, 19, 0]);
    });

    test('round-trips', () {
      const s = ReminderSettings(enabled: true, hour: 7, minute: 30);
      expect(ReminderSettings.fromJson(s.toJson()), s);
    });

    test('anything unreadable is off', () {
      for (final bad in [
        null,
        'x',
        <String, dynamic>{},
        {'enabled': 'yes', 'hour': 7, 'minute': 0},
        {'enabled': true, 'hour': 25, 'minute': 0},
        {'enabled': true, 'hour': 7, 'minute': -1},
      ]) {
        expect(ReminderSettings.fromJson(bad), const ReminderSettings.off(),
            reason: '$bad');
      }
    });
  });

  group('PracticeGame', () {
    test('wire ids map back; anything else is null', () {
      expect(PracticeGame.fromWireId('faces'), PracticeGame.faces);
      expect(PracticeGame.fromWireId('details'), PracticeGame.details);
      for (final bad in [null, '', 'Faces', 'rm -rf']) {
        expect(PracticeGame.fromWireId(bad), isNull);
      }
    });
  });

  group('ReminderTarget', () {
    final four = [
      person('a', 'Ann'),
      person('b', 'Bo'),
      person('c', 'Cy'),
      person('d', 'Di')
    ];

    test('the first playable game, honouring a playable request', () {
      expect(ReminderTarget.resolve(four, null), PracticeGame.faces);
      final withDetail = [...four.skip(1), person('a', 'Ann', detail: true)];
      expect(ReminderTarget.resolve(withDetail, PracticeGame.details),
          PracticeGame.details);
    });

    test('an unplayable request falls through; nothing playable is null', () {
      expect(ReminderTarget.resolve(four, PracticeGame.details),
          PracticeGame.faces);
      final unnamed = [
        for (final p in four) person(p.id, '', detail: p.id == 'a')
      ];
      expect(ReminderTarget.resolve(unnamed, PracticeGame.faces),
          PracticeGame.details);
      expect(ReminderTarget.resolve([], null), isNull);
    });
  });
}
