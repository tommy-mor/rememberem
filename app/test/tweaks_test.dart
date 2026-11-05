import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/memories/crop_screen.dart';
import 'package:rememberem/src/practice/device_game_feedback.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/sound/app_sound.dart';
import 'package:rememberem/src/sound/haptics.dart';
import 'package:rememberem/src/sound/sounds.dart';
import 'package:rememberem/src/speech/cued_dictation.dart';
import 'package:rememberem/src/speech/dictated_text_field.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

class _FakeSounds implements Sounds {
  final played = <AppSound>[];

  @override
  Future<void> play(AppSound sound) async => played.add(sound);
}

class _FakeHaptics implements Haptics {
  int taps = 0;

  @override
  void tap() => taps++;
}

void main() {
  group('dictation dings', () {
    late _FakeSounds sounds;
    late FakeDictation inner;
    late CuedDictation dictation;

    setUp(() {
      sounds = _FakeSounds();
      inner = FakeDictation();
      dictation = CuedDictation(inner, sounds, settle: Duration.zero);
    });

    test('a ding before listening and one when it ends', () async {
      var done = 0;
      await dictation.listen(onWords: (_) {}, onDone: () => done++);
      expect(sounds.played, [AppSound.listenStart]);
      expect(inner.isListening, isTrue);

      inner.goQuiet();
      expect(sounds.played, [AppSound.listenStart, AppSound.listenStop]);
      expect(done, 1);
    });

    test('stopping during the start ding never starts listening and dings '
        'once', () async {
      var done = 0;
      final listening = dictation.listen(onWords: (_) {}, onDone: () => done++);
      await dictation.stop();
      await listening;

      expect(inner.isListening, isFalse);
      expect(sounds.played, [AppSound.listenStart, AppSound.listenStop]);
      expect(done, 1);
    });
  });

  test('a second mic while the first listens ends the first, with its '
      'last words, before the second starts', () async {
    final sounds = _FakeSounds();
    final inner = FakeDictation();
    final dictation = CuedDictation(inner, sounds, settle: Duration.zero);
    final first = <String>[];
    final second = <String>[];
    final events = <String>[];

    await dictation.listen(
      onWords: first.add,
      onDone: () => events.add('first done'),
    );
    inner.say('Ann likes');
    await dictation.listen(
      onWords: second.add,
      onDone: () => events.add('second done'),
    );
    inner.say('jazz');

    expect(first, ['Ann likes']);
    expect(second, ['jazz']);
    expect(events, ['first done']);
    // The first was stopped, not started over (the recogniser can't).
    expect(inner.stops, 1);
    expect(inner.startedOverLive, 0);
    expect(sounds.played, [
      AppSound.listenStart,
      AppSound.listenStop,
      AppSound.listenStart,
    ]);
    expect(inner.isListening, isTrue);
  });

  test('three mics tapped quickly leave only the last one listening, and '
      'each earlier one ends once', () async {
    final sounds = _FakeSounds();
    final inner = FakeDictation();
    final dictation = CuedDictation(inner, sounds, settle: Duration.zero);
    final done = <String>[];
    final third = <String>[];

    await dictation.listen(onWords: (_) {}, onDone: () => done.add('a'));
    final b = dictation.listen(onWords: (_) {}, onDone: () => done.add('b'));
    final c = dictation.listen(onWords: third.add, onDone: () => done.add('c'));
    await b;
    await c;
    inner.say('Bo');

    expect(done, ['a', 'b']);
    expect(third, ['Bo']);
    expect(inner.startedOverLive, 0);
    expect(inner.isListening, isTrue);
  });

  test(
    'a listen replaced during its start ding ends without a stop ding',
    () async {
      final sounds = _FakeSounds();
      final inner = FakeDictation();
      final dictation = CuedDictation(inner, sounds, settle: Duration.zero);
      var done = 0;

      final first = dictation.listen(onWords: (_) {}, onDone: () => done++);
      final second = dictation.listen(onWords: (_) {}, onDone: () {});
      await first;
      await second;

      expect(done, 1);
      expect(sounds.played, [AppSound.listenStart, AppSound.listenStart]);
      expect(inner.isListening, isTrue);
    },
  );

  test('game feedback: a tap only while vibration is on; sounds always '
      'asked for (the player checks the sound setting)', () {
    final settings = AppSettingsController();
    final sounds = _FakeSounds();
    final haptics = _FakeHaptics();
    final feedback = DeviceGameFeedback(settings, sounds, haptics);

    feedback.right();
    feedback.wrong();
    expect(haptics.taps, 1);
    expect(sounds.played, [AppSound.right, AppSound.wrong]);

    settings.update(settings.value.copyWith(vibration: false));
    feedback.right();
    expect(haptics.taps, 1);
  });

  group('crop', () {
    test('untouched, the frame shows the centre of a wide photo', () {
      final rect = CropScreen.visibleRect(
        imageWidth: 1000,
        imageHeight: 500,
        frame: const Size(200, 250),
        matrix: Matrix4.identity(),
      );
      // Covering 200x250 scales the photo by 0.5: 500x250 shown as 200 wide.
      expect(rect, const PixelRect(300, 0, 400, 500));
    });

    test('zoomed in twice on the top left corner of the frame', () {
      final rect = CropScreen.visibleRect(
        imageWidth: 400,
        imageHeight: 500,
        frame: const Size(400, 500),
        matrix: Matrix4.diagonal3Values(2, 2, 1),
      );
      expect(rect, const PixelRect(0, 0, 200, 250));
    });

    test('dragged left by half the frame shows the right half', () {
      final rect = CropScreen.visibleRect(
        imageWidth: 400,
        imageHeight: 500,
        frame: const Size(400, 500),
        matrix: Matrix4.diagonal3Values(2, 2, 1)..setTranslationRaw(-400, 0, 0),
      );
      expect(rect, const PixelRect(200, 0, 200, 250));
    });
  });

  testWidgets('the mic pulses only while listening, so the screen settles', (
    tester,
  ) async {
    final dictation = FakeDictation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictatedTextField(
            label: 'Name',
            initialValue: '',
            dictation: dictation,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();
    expect(find.byType(FadeTransition), findsWidgets);
    expect(tester.hasRunningAnimations, isTrue);

    dictation.goQuiet();
    await tester.pumpAndSettle(); // would time out if it kept pulsing
    expect(find.byTooltip('Speak Name'), findsOneWidget);
  });

  testWidgets('tapping off a field closes the keyboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeMemoryRepository();
    await repository.add(photoJpeg: [], capturedAt: DateTime(2026));
    await tester.pumpWidget(RememberemApp(services: testServices(repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();
    bool typing() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;

    await tester.tap(find.widgetWithText(TextField, 'NAME'));
    await tester.pump();
    expect(typing(), isTrue);

    // The photo is not a button: tapping it is tapping off the field.
    await tester.tapAt(tester.getCenter(find.byType(Image).first));
    await tester.pump();
    expect(typing(), isFalse);
  });
}
