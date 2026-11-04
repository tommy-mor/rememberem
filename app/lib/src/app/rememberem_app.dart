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
  StreamSubscription<String?>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.shortcut?.install(_meetSomeone);
    final scheduler = widget.services.reminders?.scheduler;
    if (scheduler != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Listen first, so a tap during the launch check is not lost.
        _taps = scheduler.taps.listen(_openNotification);
        _openNotification(await scheduler.launchPayload());
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
      // Back from the phone's settings, perhaps with location changed.
      unawaited(
        widget.services.placeNotices?.sync().catchError(
          (Object e) =>
              debugPrint('Rememberem: place sync failed: ${e.runtimeType}'),
        ),
      );
      unawaited(
        widget.services.reminders?.sync().catchError(
          (Object e) =>
              debugPrint('Rememberem: reminder sync failed: ${e.runtimeType}'),
        ),
      );
    }
  }

  /// Opens the camera over the list, which drops its filters so the
  /// person about to be met is not hidden behind them. Ignored if the
  /// camera is already the page on top (once it hands over to the notes
  /// page, it works again).
  void _meetSomeone() {
    if (_topRouteIn({AppRoutes.capture})) return;
    widget.services.listFilters.show(const []);
    _openOnRoot(
      AppRoutes.capture,
      (_) => CaptureScreen(services: widget.services),
      blockedBy: {AppRoutes.capture},
    );
  }

  /// A notification was tapped. Its payload is untrusted: anything that is
  /// not a game or a notice's day does nothing.
  void _openNotification(String? payload) {
    if (PracticeGame.fromWireId(payload) case final game?) {
      _openReminder(game);
    } else if (AnniversaryNotice.dayFromWire(payload) case final day?) {
      _openAnniversaries(day);
    } else if (PlaceNotice.fenceFromWire(payload) case final fence?) {
      _openPlace(fence);
    }
  }

  /// A place notice was tapped: the list, filtered to that place. Never
  /// over the camera or a game, and not if the place is gone.
  Future<void> _openPlace(String fence) async {
    const blockedBy = {AppRoutes.capture, AppRoutes.practice};
    if (_topRouteIn(blockedBy)) return;
    try {
      final people = await widget.services.repository.all();
      final places = {
        for (final m in people)
          for (final e in m.encounters)
            if (e.place.trim().isNotEmpty) e.place.trim(),
      };
      final place = PlaceNotice.placeFor(fence, places);
      final navigator = _navigator.currentState;
      if (place == null || !mounted || navigator == null) return;
      if (_topRouteIn(blockedBy)) return;
      navigator.popUntil((route) => route.isFirst);
      widget.services.listFilters.show([PlaceFilter(place)]);
    } catch (_) {
      // A notice must never break the app; the list stays.
    }
  }

  /// An anniversary notice was tapped: the list, filtered to the notice's
  /// week (replacing any filters). Never over the camera or a game, and
  /// not if no one matches any more (the list stays as it was).
  Future<void> _openAnniversaries(LocalDay day) async {
    const blockedBy = {AppRoutes.capture, AppRoutes.practice};
    if (_topRouteIn(blockedBy)) return;
    final filter = AnniversaryNotice.filterFor(day);
    try {
      final people = await widget.services.repository.all();
      final navigator = _navigator.currentState;
      if (!people.any(filter.matches) || !mounted || navigator == null) return;
      if (_topRouteIn(blockedBy)) return;
      navigator.popUntil((route) => route.isFirst);
      widget.services.listFilters.show([filter]);
    } catch (_) {
      // A notice must never break the app; the list stays.
    }
  }

  /// A reminder was tapped: open a game Fred can play now, over the list.
  /// Never while the camera or a game is open.
  Future<void> _openReminder(PracticeGame requested) async {
    if (_topRouteIn({AppRoutes.capture, AppRoutes.practice})) return;
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
        themeMode: settings.darkPages ? ThemeMode.dark : ThemeMode.light,
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
