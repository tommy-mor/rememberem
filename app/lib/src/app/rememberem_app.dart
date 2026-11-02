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
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    widget.shortcut?.install(_meetSomeone);
  }

  Future<void> _meetSomeone() async {
    final navigator = _navigator.currentState;
    if (navigator == null || _capturing) return;
    _capturing = true;
    try {
      navigator.popUntil((route) => route.isFirst);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CaptureScreen(services: widget.services),
        ),
      );
    } finally {
      _capturing = false;
    }
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
