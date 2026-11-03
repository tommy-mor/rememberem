import 'package:flutter/widgets.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Distances in the units Fred chose, or his phone region's.
class Units {
  const Units._();

  static bool metric(AppSettings settings) => settings.metricFor(
    WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );

  static String distance(AppSettings settings, double meters) =>
      Distance.format(meters, metric: metric(settings));
}
