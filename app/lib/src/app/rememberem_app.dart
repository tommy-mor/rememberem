import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../capture/capture_screen.dart';
import '../memories/memory_list_screen.dart';
import '../practice/practice_screens.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'meet_shortcut.dart';
import 'rememberem_theme.dart';

class RememberemApp extends StatefulWidget {
  const RememberemApp({super.key, required this.services, this.shortcut});

  final AppServices services;

  /// Null in tests, where there is no platform to install it on.
  final MeetShortcut? shortcut;

  @override
  State<RememberemApp> createState() => _RememberemAppState();
}

class _RememberemAppState extends State<RememberemApp>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _routeObserver = RouteObserver<ModalRoute<void>>();
  StreamSubscription<PracticeGame?>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shortcut?.install(_meetSomeone);
    final scheduler = widget.services.reminders?.scheduler;
    if (scheduler != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Listen first, so a tap during the launch check is not lost.
        _taps = scheduler.taps.listen(_openReminder);
        _openReminder(await scheduler.launchGame());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    super.dispose();
  }

  /// Coming back to the app: people may have been added or removed, or the
  /// time zone changed, so bring the reminder up to date.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        widget.services.reminders?.sync().catchError(
          (Object e) => debugPrint('Rememberem: reminder sync failed: $e'),
        ),
      );
    }
  }

  /// Opens the camera over the list. Ignored if the camera is already the
  /// page on top (once it hands over to the notes page, it works again).
  void _meetSomeone() => _openOnRoot(
    AppRoutes.capture,
    (_) =>
        CaptureScreen(services: widget.services, routeObserver: _routeObserver),
    blockedBy: {AppRoutes.capture},
  );

  /// A reminder was tapped: open a game Fred can play now, over the list.
  /// Never while the camera or a game is open; untrusted or unknown
  /// payloads (null) do nothing.
  Future<void> _openReminder(PracticeGame? requested) async {
    if (requested == null ||
        _topRouteIn({AppRoutes.capture, AppRoutes.practice})) {
      return;
    }
    try {
      final repository = widget.services.repository;
      final game = ReminderTarget.resolve(await repository.all(), requested);
      if (game == null || !mounted) return; // nothing to practise: the list
      _openOnRoot(
        AppRoutes.practice,
        (_) => PracticeScreens.build(game, widget.services),
        blockedBy: {AppRoutes.capture, AppRoutes.practice},
      );
    } catch (_) {
      // A reminder must never break the app; the list stays.
    }
  }

  /// Opens a page directly over the list, closing anything above the list
  /// first (a card left this way still saves). Does nothing if the page on
  /// top is one of [blockedBy].
  void _openOnRoot(
    String name,
    WidgetBuilder builder, {
    required Set<String> blockedBy,
  }) {
    final navigator = _navigator.currentState;
    if (navigator == null || _topRouteIn(blockedBy)) return;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: builder,
      ),
    );
  }

  bool _topRouteIn(Set<String> names) {
    final navigator = _navigator.currentState;
    if (navigator == null) return false;
    var onTop = false;
    navigator.popUntil((route) {
      onTop = names.contains(route.settings.name);
      return true; // only looks at the top route
    });
    return onTop;
  }

  @override
  Widget build(BuildContext context) {
    // The list is built once: rebuilding the app for a colour change must
    // not rebuild (and reload) the page under it.
    final home = MemoryListScreen(
      services: widget.services,
      routeObserver: _routeObserver,
      onMeetSomeone: _meetSomeone,
    );
    return ValueListenableBuilder<AppSettings>(
      valueListenable: widget.services.settings,
      builder: (context, settings, _) => MaterialApp(
        title: 'Rememberem',
        navigatorKey: _navigator,
        navigatorObservers: [_routeObserver],
        theme: RememberemTheme.light(settings),
        darkTheme: RememberemTheme.dark(settings),
        themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        // Tapping anywhere that is not a button or field closes the
        // keyboard.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        home: home,
      ),
    );
  }
}
