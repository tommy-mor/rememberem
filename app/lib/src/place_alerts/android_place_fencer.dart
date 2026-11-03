import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_alert_access.dart';
import 'place_fencer.dart';

/// [PlaceFencer] on Android's geofencing (`PlaceFences.kt`). The phone's
/// location service does the watching; nothing leaves the phone.
class AndroidPlaceFencer implements PlaceFencer {
  AndroidPlaceFencer() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'rememberem/place_fences';
  static const _channel = MethodChannel(channelName);

  /// Place names longer than this are cut (a forged tap could be any size).
  static const maxNameLength = 200;

  final _taps = StreamController<String>.broadcast();
  bool _launchTaken = false;

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'tap') return;
    final place = clean(call.arguments);
    if (place != null) _taps.add(place);
  }

  /// A tapped place name, trimmed and cut to size; null if it is not one.
  static String? clean(Object? value) {
    if (value is! String) return null;
    final name = value.trim();
    if (name.isEmpty) return null;
    return name.length > maxNameLength
        ? name.substring(0, maxNameLength)
        : name;
  }

  static PlaceAlertAccess _access(Object? value) =>
      PlaceAlertAccess.values.where((a) => a.name == value).firstOrNull ??
      PlaceAlertAccess.location;

  @override
  Future<PlaceAlertAccess?> access() async {
    try {
      return _access(await _channel.invokeMethod<String>('access'));
    } catch (error) {
      // Can't tell: the caller keeps Fred's setting as it is.
      debugPrint('Rememberem: place access check failed: $error');
      return null;
    }
  }

  @override
  Future<PlaceAlertAccess> requestAccess() async {
    try {
      return _access(await _channel.invokeMethod<String>('requestAccess'));
    } catch (_) {
      return PlaceAlertAccess.location;
    }
  }

  @override
  Future<bool> replace(List<PlaceFence> fences) async {
    try {
      return await _channel.invokeMethod<bool>('replace', [
            for (final fence in fences) fence.toJson(),
          ]) ??
          false;
    } catch (error) {
      debugPrint('Rememberem: watching places failed: $error');
      return false;
    }
  }

  @override
  Future<String?> launchPlace() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    try {
      return clean(await _channel.invokeMethod<String>('launchPlace'));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }
}
