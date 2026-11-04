import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_arrived.dart';
import 'place_fences.dart';

/// [PlaceFences] on the phone's own geofencing. Only opaque ids and
/// circles are handed over, never a name. Android waits until Fred has
/// stayed a few minutes, so driving past never counts.
class NativePlaceFences implements PlaceFences {
  Future<void>? _ready;

  /// Set up once; a failed set-up is tried again next time.
  Future<void> _init() => _ready ??= NativeGeofenceManager.instance
      .initialize()
      .catchError((Object error) {
        _ready = null;
        throw error;
      });

  static const _stay = Duration(minutes: 3);

  @override
  Future<void> sync(List<PlaceFence> fences) async {
    await _init();
    final manager = NativeGeofenceManager.instance;
    final wanted = {for (final f in fences) f.id};
    var failed = false;
    Future<void> attempt(Future<void> Function() step) async {
      if (!await _try(step)) failed = true;
    }

    for (final active in await manager.getRegisteredGeofences()) {
      if (!wanted.contains(active.id)) {
        await attempt(() => manager.removeGeofenceById(active.id));
      }
    }
    // Every wanted fence is added again, replacing it by id: the phone can
    // drop fences (location off, Play services reset) while the plugin
    // still lists them.
    for (final fence in fences) {
      await attempt(
        () => manager.createGeofence(
          Geofence(
            id: fence.id,
            location: Location(
              latitude: fence.at.latitude,
              longitude: fence.at.longitude,
            ),
            radiusMeters: fence.meters,
            triggers: {GeofenceEvent.enter, GeofenceEvent.dwell},
            iosSettings: const IosGeofenceSettings(),
            androidSettings: const AndroidGeofenceSettings(
              initialTriggers: {},
              loiteringDelay: _stay,
            ),
          ),
          placeArrived,
        ),
      );
    }
    // Every fence was tried; say if any failed (so turning on can tell).
    if (failed) throw StateError('Some place fences failed');
  }

  @override
  Future<void> clear() async {
    await _init();
    await NativeGeofenceManager.instance.removeAllGeofences();
  }

  /// One fence's trouble (gone already, or refused) is logged by kind and
  /// passed over, so the rest still go ahead; false if it failed.
  static Future<bool> _try(Future<void> Function() step) async {
    try {
      await step();
      return true;
    } catch (error) {
      debugPrint('Rememberem: a place fence failed: ${error.runtimeType}');
      return false;
    }
  }
}
