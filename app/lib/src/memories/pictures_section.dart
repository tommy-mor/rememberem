import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';

/// The [encounters] given (the person's other pictures, newest first),
/// each with when and where it was taken, under a "Pictures" header.
/// Tapping one opens it.
class PicturesSection extends StatelessWidget {
  const PicturesSection({
    super.key,
    required this.encounters,
    required this.repository,
    required this.onOpen,
  });

  final List<Encounter> encounters;
  final MemoryRepository repository;
  final void Function(Encounter encounter) onOpen;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Pictures', count: encounters.length),
        for (final encounter in encounters)
          ListTile(
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: RememberemTheme.gutter,
            ),
            horizontalTitleGap: RememberemTheme.thumbGap,
            minLeadingWidth: RememberemTheme.thumbRow.width,
            leading: PortraitThumb(photo: repository.encounterPhoto(encounter)),
            title: Text(
              localizations.formatFullDate(encounter.capturedAt.toLocal()),
            ),
            subtitle: Text(
              [
                localizations.formatTimeOfDay(
                  TimeOfDay.fromDateTime(encounter.capturedAt.toLocal()),
                ),
                encounter.place,
                encounter.meeting,
              ].where((s) => s.trim().isNotEmpty).join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onOpen(encounter),
          ),
      ],
    );
  }
}
