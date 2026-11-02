import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Every picture of a person, newest first, each with when and where it was
/// taken. Tapping one opens it.
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
        Text('Pictures', style: Theme.of(context).textTheme.titleSmall),
        for (final encounter in encounters)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                repository.encounterPhoto(encounter),
                width: 48,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 48, child: Icon(Icons.person)),
              ),
            ),
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpen(encounter),
          ),
      ],
    );
  }
}
