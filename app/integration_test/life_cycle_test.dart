import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/capture/ml_kit_face_locator.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/capture/picked_photo.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../test/fakes/test_services.dart';

/// Hands over the bundled test portrait as if Fred chose it.
class _PortraitPicker implements PhotoPicker {
  _PortraitPicker(this.bytes);

  final List<int> bytes;

  @override
  Future<PickedPhoto?> pick() async => PickedPhoto(bytes, original: true);

  @override
  Future<void> openSettings() async {}
}

/// One person's life in the app on a real device: capture with real face
/// detection, name, restart, trash and restore. Everything is kept in a
/// temp folder, never the app's own records. Allow the camera first
/// (`adb shell pm grant com.rememberem.rememberem android.permission.CAMERA`)
/// so no prompt covers the screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late List<int> portrait;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('life_test_');
    portrait = (await rootBundle.load('integration_test/assets/portrait.jpg'))
        .buffer
        .asUint8List();
  });

  tearDown(() => temp.delete(recursive: true));

  /// The app over the records in [temp], as a fresh start would see them.
  Future<JsonFileMemoryRepository> start(WidgetTester tester) async {
    final repository = JsonFileMemoryRepository(
      Directory('${temp.path}/memories'),
    );
    final services = testServices(
      repository,
      capture: PortraitCapture(
        repository: repository,
        faceLocator: MlKitFaceLocator(),
        workFolder: Directory('${temp.path}/work'),
      ),
      photoPicker: _PortraitPicker(portrait),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RememberemApp(services: services));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('capture, name, restart, trash and restore', (tester) async {
    await start(tester);

    await tester.tap(find.text('Meet someone'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    for (
      var i = 0;
      i < 50 && find.byType(MemoryEditScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(MemoryEditScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Integration Ivy',
    );
    await tester.pump(const Duration(seconds: 2)); // autosave
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Integration Ivy'), findsOneWidget);

    // Restart: a new repository over the same files.
    var repository = await start(tester);
    expect(find.text('Integration Ivy'), findsOneWidget);
    final saved = (await repository.all()).single;
    final photo = await decodeImageFromList(
      await repository.photoFile(saved).readAsBytes(),
    );
    expect(photo.height / photo.width, closeTo(PortraitFramer.aspect, 0.02));

    await tester.tap(find.text('Integration Ivy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    expect(find.text('Integration Ivy'), findsNothing);

    repository = await start(tester);
    expect(find.text('Integration Ivy'), findsNothing);
    await tester.tap(find.byTooltip('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restore'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Integration Ivy'), findsOneWidget);
    expect((await repository.all()).single.displayName, 'Integration Ivy');
  });
}
