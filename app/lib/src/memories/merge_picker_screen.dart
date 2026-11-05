import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/bottom_action_bar.dart';
import '../app/empty_state.dart';
import '../app/home_button.dart';
import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../app/selected_row.dart';
import 'date_groups.dart';
import 'memory_tile.dart';

/// Picks the existing person to merge [source] into: a tap picks someone
/// (a second tap on them lets go) and Merge pops with the chosen [Memory].
/// Back pops with null, merging no one.
class MergePickerScreen extends StatefulWidget {
  const MergePickerScreen({
    super.key,
    required this.repository,
    required this.source,
    this.clock = DateTime.now,
  });

  final MemoryRepository repository;

  /// The person being merged, who is never offered.
  final Memory source;

  /// For the date headings.
  final DateTime Function() clock;

  @override
  State<MergePickerScreen> createState() => _MergePickerScreenState();
}

class _MergePickerScreenState extends State<MergePickerScreen> {
  late final Future<List<Memory>> _people = widget.repository.all();

  /// The pick, by id, so it survives a rotation.
  String? _pickedId;

  /// Set when Merge is pressed, so a second press does nothing.
  bool _merging = false;

  void _pick(Memory person) => setState(() {
    _pickedId = _pickedId == person.id ? null : person.id;
  });

  void _merge(List<Memory> people) {
    if (_merging) return;
    final picked = people.where((m) => m.id == _pickedId).firstOrNull;
    if (picked == null) return;
    setState(() => _merging = true);
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final name = MemoryTile.nameOf(widget.source);
    return FutureBuilder<List<Memory>>(
      future: _people,
      builder: (context, snapshot) {
        final loaded = snapshot.data;
        final people = [
          for (final m in loaded ?? <Memory>[])
            if (m.id != widget.source.id) m,
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text('Merge $name into…'),
            actions: const [HomeButton()],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _source(context, name),
              Expanded(child: _body(loaded == null, people)),
            ],
          ),
          bottomNavigationBar: _pickedId == null
              ? null
              : BottomActionBar(
                  end: FilledButton(
                    style: BottomActionBar.goldStyle,
                    onPressed: _merging ? null : () => _merge(people),
                    child: const Text('Merge'),
                  ),
                ),
        );
      },
    );
  }

  /// Pinned above the list: whom this merges.
  Widget _source(BuildContext context, String name) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(
        horizontal: RememberemTheme.gutter,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: RememberemTheme.shade(theme, theme.colorScheme.surface),
        border: Border(bottom: BorderSide(color: RememberemTheme.rule(theme))),
      ),
      child: Row(
        children: [
          PortraitThumb(photo: widget.repository.photoFile(widget.source)),
          const SizedBox(width: RememberemTheme.thumbGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'will be merged into the person you pick',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(bool loading, List<Memory> people) {
    if (loading) {
      return const Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(minHeight: 3, semanticsLabel: 'Loading'),
      );
    }
    if (people.isEmpty) {
      return const EmptyState(title: 'No one else to merge with.');
    }
    final rows = <Object>[
      for (final group in DateGroups(
        widget.clock,
      ).group(people, (m) => m.capturedAt)) ...[group.label, ...group.items],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is! Memory) {
          return SectionHeader(title: row as String, tinted: false);
        }
        return SelectedRow(
          selected: row.id == _pickedId,
          child: MemoryTile(
            memory: row,
            photo: widget.repository.photoFile(row),
            onTap: () => _pick(row),
          ),
        );
      },
    );
  }
}
