import 'package:flutter/material.dart';

import '../capture/capture_screen.dart';
import '../memories/memory_list_screen.dart';
import 'app_services.dart';
import 'meet_shortcut.dart';

class RememberemApp extends StatefulWidget {
  const RememberemApp({super.key, required this.services, this.shortcut});

  final AppServices services;

  /// Null in tests, where there is no platform to install it on.
  final MeetShortcut? shortcut;

  @override
  State<RememberemApp> createState() => _RememberemAppState();
}

class _RememberemAppState extends State<RememberemApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _routeObserver = RouteObserver<ModalRoute<void>>();

  /// Names the camera page, so a second trigger can see it is already open.
  static const _captureRoute = 'capture';

  @override
  void initState() {
    super.initState();
    widget.shortcut?.install(_meetSomeone);
  }

  /// Opens the camera over the list. Ignored if the camera is already the
  /// page on top (once it hands over to the notes page, it works again).
  void _meetSomeone() {
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    var cameraOnTop = false;
    navigator.popUntil((route) {
      cameraOnTop = route.settings.name == _captureRoute;
      return true; // only looks at the top route
    });
    if (cameraOnTop) return;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: _captureRoute),
        builder: (_) => CaptureScreen(services: widget.services),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rememberem',
      navigatorKey: _navigator,
      navigatorObservers: [_routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: MemoryListScreen(
        services: widget.services,
        routeObserver: _routeObserver,
        onMeetSomeone: _meetSomeone,
      ),
    );
  }
}
