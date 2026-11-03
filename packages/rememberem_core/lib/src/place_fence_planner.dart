import 'dart:math';

import 'app_settings.dart';
import 'memory.dart';
import 'place_book.dart';
import 'place_fence.dart';

/// Which places to watch for Fred arriving: every named place with a
/// location whose notifications are on.
class PlaceFencePlanner {
  const PlaceFencePlanner._();

  /// Android watches at most 100 places for one app.
  static const maxFences = 100;

  /// Smaller circles are missed by the phone's location service.
  static const minRadiusMeters = 150.0;

  /// The fences for [active] people (not the trash), newest place first;
  /// none when place notifications are off.
  static List<PlaceFence> plan(List<Memory> active, AppSettings settings) {
    if (!settings.placeAlerts) return const [];
    final radius = max(settings.placeFinder.radiusMeters, minRadiusMeters);
    final groups = [
      for (final group in PlaceBook.from(active).groups)
        if (group.name case final name?
            when group.marker != null && settings.alertsFor(name))
          group,
    ]..sort((a, b) {
        final byTime = b.newest.compareTo(a.newest);
        return byTime != 0 ? byTime : a.name!.compareTo(b.name!);
      });
    return [
      for (final group in groups.take(maxFences))
        PlaceFence(
          name: group.name!,
          center: group.marker!,
          radiusMeters: radius,
        ),
    ];
  }
}
