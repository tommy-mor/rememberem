import 'package:quick_actions/quick_actions.dart';

/// The "Meet someone" app shortcut. Long-press the app icon to see it; on
/// Android it can be dragged onto the home screen as its own button.
class MeetShortcut {
  static const type = 'meet_someone';

  final QuickActions _quickActions = const QuickActions();

  /// Calls [onMeet] when the shortcut is used, including when it is what
  /// launched the app.
  Future<void> install(void Function() onMeet) async {
    await _quickActions.initialize((tapped) {
      if (tapped == type) onMeet();
    });
    await _quickActions.setShortcutItems(const [
      ShortcutItem(
        type: type,
        localizedTitle: 'Meet someone',
        icon: 'ic_shortcut_camera',
      ),
    ]);
  }
}
