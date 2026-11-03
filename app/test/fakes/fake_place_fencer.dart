import 'dart:async';

import 'package:rememberem/src/place_alerts/place_alert_access.dart';
import 'package:rememberem/src/place_alerts/place_fencer.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Records what the app asks of the phone's geofencing, and lets a test tap
/// arrival notices.
class FakePlaceFencer implements PlaceFencer {
  FakePlaceFencer({this.allowed = PlaceAlertAccess.granted, this.launch});

  /// What [access] reports.
  PlaceAlertAccess allowed;

  /// What [requestAccess] leaves [allowed] as (default: unchanged).
  PlaceAlertAccess? afterRequest;

  /// What [replace] answers.
  bool replaceWorks = true;

  String? launch;
  final List<String> calls = [];

  /// The fences from the latest [replace].
  List<PlaceFence>? watched;
  final _taps = StreamController<String>.broadcast();

  void emitTap(String place) => _taps.add(place);

  @override
  Future<PlaceAlertAccess?> access() async => unknown ? null : allowed;

  /// When true, [access] can't tell (a channel error).
  bool unknown = false;

  @override
  Future<PlaceAlertAccess> requestAccess() async {
    calls.add('request');
    allowed = afterRequest ?? allowed;
    return allowed;
  }

  @override
  Future<bool> replace(List<PlaceFence> fences) async {
    calls.add('replace ${fences.map((f) => f.name).join(',')}');
    watched = fences;
    return replaceWorks;
  }

  @override
  Future<String?> launchPlace() async {
    final place = launch;
    launch = null;
    return place;
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> openSettings() async => calls.add('settings');
}
