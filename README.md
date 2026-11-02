# Rememberem

A Flutter app for Android and iOS that helps you remember the people you meet.
Take someone's photo and it's cropped to head and shoulders. Then speak or type
their name, where you met, the meeting, and anything else worth remembering.
Everything saves automatically and stays private to the app.

## Layout

| Path | What lives there |
| --- | --- |
| `app/` | The Flutter app. `android/` and `ios/` hold the native projects. `lib/` is shared by both platforms. |
| `packages/rememberem_core/` | Code shared across platforms that doesn't need Flutter: the `Memory` record, private file storage, head-and-shoulders framing and cropping, and the capture pipeline. Its tests run on any machine with the Dart SDK. |

Inside `app/lib/src/`:

- `app/`: the app shell, its shared services, and the "Meet someone" shortcut
- `capture/`: the camera screen and ML Kit face detection
- `memories/`: the list of people and the notes screen with autosave
- `speech/`: microphone-enabled text fields (speech to text)
- `location/`: the device's GPS position

## Setup

1. Install Flutter (stable). On this machine it's at `C:\src\flutter`, so add
   `C:\src\flutter\bin` to `PATH`.
2. Run `flutter doctor` and fix anything it reports for Android (and Xcode on a Mac).

## Commands

```sh
# Shared core
cd packages/rememberem_core
dart test

# App
cd app
flutter analyze
flutter test                                  # unit + widget tests
flutter test integration_test -d <device>     # real ML Kit face detection, on a device/emulator
flutter run -d <device>
flutter build apk                             # Android
flutter build ipa                             # iOS (macOS + Xcode only)
```

## Platform notes

- **iOS** has to be built on a Mac with Xcode. The minimum version is iOS 15.5,
  which Google ML Kit needs. The permission prompts are defined in
  `ios/Runner/Info.plist`.
- **Android**: `android/gradle.properties` turns off Kotlin incremental
  compilation. Without that, Windows builds fail when the project and the pub
  cache are on different drives.
- **The home-screen shortcut**: long-press the Rememberem icon to get
  **Meet someone**, which opens straight to the camera. On Android you can drag
  that item onto the home screen as a button of its own. On iOS it stays in the
  long-press menu.

## Storage

Each person is stored as `<id>.json` next to `<id>.jpg` in the app's private
documents folder (`memories/`). Photos never go to the gallery. A record's
`fields` map is open-ended: the screen shows `name`, `place` and `meeting`, and
other keys (age, interests, ...) can be added without a migration. Details are a
separate list (`detailItems`), each with its text and the time it was recorded.
