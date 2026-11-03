import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_alert_access.dart';
import 'place_alert_coordinator.dart';
import 'place_alert_explainer.dart';

/// Turn place notifications on or off, and choose which places notify.
/// Part of the Settings page; rebuilt there when the settings change.
class PlaceAlertsSection extends StatefulWidget {
  const PlaceAlertsSection({super.key, required this.coordinator});

  final PlaceAlertCoordinator coordinator;

  /// What to tell Fred when something is still missing.
  static String missingText(PlaceAlertAccess missing) => switch (missing) {
    PlaceAlertAccess.granted => '',
    PlaceAlertAccess.notifications =>
      'Notifications are blocked for Rememberem.',
    PlaceAlertAccess.location =>
      'Rememberem needs precise location to notice where you are.',
    PlaceAlertAccess.background =>
      'Choose "Allow all the time" for location, then come back.',
  };

  static const switchLabel = 'Notify me when I arrive';

  static const unavailableText =
      "Your phone can't watch places right now. Check that location is on.";

  @override
  State<PlaceAlertsSection> createState() => _PlaceAlertsSectionState();
}

class _PlaceAlertsSectionState extends State<PlaceAlertsSection>
    with WidgetsBindingObserver {
  PlaceAlertCoordinator get _coordinator => widget.coordinator;

  /// Named places with a location: only those can notify.
  List<String>? _places;
  PlaceAlertAccess _missing = PlaceAlertAccess.granted;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlaces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the app: after a trip to the phone's Settings, see whether
  /// Fred allowed it; otherwise wait for the app's own sync, so the
  /// "can't watch" line is up to date either way.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final waiting = _missing != PlaceAlertAccess.granted;
    (waiting ? _coordinator.sync() : _coordinator.settled()).then((_) async {
      final access = waiting ? await _coordinator.fencer.access() : null;
      if (!mounted) return;
      setState(() {
        if (access != null) _missing = access;
      });
    }).ignore();
  }

  Future<void> _loadPlaces() async {
    try {
      final groups = PlaceBook.from(await _coordinator.repository.all()).groups;
      final places = [
        for (final g in groups)
          if (g.name != null && g.marker != null) g.name!,
      ];
      if (mounted) setState(() => _places = places);
    } catch (_) {
      if (mounted) setState(() => _places = const []);
    }
  }

  Future<void> _setEnabled(bool on) async {
    if (on && !await PlaceAlertExplainer.show(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    var missing = PlaceAlertAccess.granted;
    try {
      missing = await _coordinator.setEnabled(on);
    } catch (_) {
      // Could not save; the switch shows what is actually set.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _missing = missing;
        });
      }
    }
  }

  Future<void> _setPlace(String place, bool on) async {
    try {
      await _coordinator.setPlace(place, on);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _coordinator.settings.value;
    final small = Theme.of(context).textTheme.bodySmall;
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    final places = _places;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text(PlaceAlertsSection.switchLabel),
          subtitle: const Text(
            'A notice when you arrive at a place where you met people. '
            'Tap it to see who.',
          ),
          value: settings.placeAlerts,
          onChanged: _busy ? null : _setEnabled,
        ),
        if (_missing != PlaceAlertAccess.granted && !settings.placeAlerts)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    PlaceAlertsSection.missingText(_missing),
                    style: error,
                  ),
                ),
                TextButton(
                  onPressed: () => _coordinator.fencer.openSettings(),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        if (settings.placeAlerts && _coordinator.unavailable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(PlaceAlertsSection.unavailableText, style: error),
          ),
        ExpansionTile(
          title: const Text('Places'),
          subtitle: Text(
            'Checked places notify you. Home, work and church start '
            'unchecked.',
            style: small,
          ),
          children: [
            if (places == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (places.isEmpty)
              const ListTile(title: Text('No places with a location yet.'))
            else
              for (final place in places)
                CheckboxListTile(
                  title: Text(place),
                  value: settings.alertsFor(place),
                  onChanged: (v) => _setPlace(place, v ?? false),
                ),
          ],
        ),
      ],
    );
  }
}
