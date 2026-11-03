# Release steps

What to do before any build reaches someone else (CLAUDE.md, "Before every
deployment"). Run from `app/` with Flutter on PATH
(`export PATH="/c/src/flutter/bin:$PATH"`).

## Once: the upload key

Play App Signing holds the real signing key; you sign uploads with an upload
key. Keep the key and its passwords somewhere safe outside the repo, and
back them up. Losing them means asking Play to reset the upload key.

```sh
keytool -genkeypair -v -keystore C:/Users/ericj/keys/rememberem-upload.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Then create `app/android/key.properties` (git-ignored):

```properties
storeFile=C:/Users/ericj/keys/rememberem-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without that file a release build stops with "No upload key". A
debug-signed build in someone's hands can never be updated by a Play build
without them losing their people. For a release walk on your own emulator
or phone only, sign with the debug key on purpose:

```sh
flutter build apk --release -PallowDebugSigning=true
```

## Every release

1. Bump `version:` in `app/pubspec.yaml` (the build number after `+` must
   rise every upload).
2. The check-in checks: core and app analyze, tests and debug build.
3. Integration tests on the emulator **and** the phone. Allow the camera
   first, so no prompt covers the screen:
   ```sh
   adb -s <device> shell pm grant com.rememberem.rememberem android.permission.CAMERA
   flutter test integration_test -d <device>
   ```
   They use a temp folder, never the app's own records, but they reinstall
   the debug build. On the phone, back up first.
4. `flutter build apk --release`, install it, and walk capture, a group
   photo, dictation, a reminder firing and both practice games (`fred`).
   Release builds shrink code, which has broken plugins before.
5. Run the Release readiness crew, ending with `vera`.
6. `flutter build appbundle` and upload
   `build/app/outputs/bundle/release/app-release.aab`.
7. **Eric deploys.** A recommendation to ship is not permission to ship.
