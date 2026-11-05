import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/empty_state.dart';
import '../app/home_button.dart';
import '../app/pill_button.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../memories/date_groups.dart';
import '../memories/memory_tile.dart';
import 'purge_confirm_dialog.dart';

/// People moved to the trash. Each can be restored, or deleted forever
/// after a confirmation.
class TrashScreen extends StatefulWidget {
  const TrashScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
  });

  final MemoryRepository repository;

  /// Decides which day "Today" is.
  final DateTime Function() clock;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Memory>? _trashed;
  int _reloadGen = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    final trashed = await widget.repository.trashed();
    if (mounted && gen == _reloadGen) setState(() => _trashed = trashed);
  }

  Future<void> _restore(Memory memory) async {
    await widget.repository.restore(memory.id);
    await _reload();
  }

  Future<void> _purge(Memory memory) async {
    final confirmed = await PurgeConfirmDialog.show(
      context,
      MemoryTile.nameOf(memory),
    );
    if (!confirmed) return;
    await widget.repository.purge(memory.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final trashed = _trashed;
    return Scaffold(
      appBar: AppBar(
        title: trashed == null || trashed.isEmpty
            ? const Text('Trash')
            : RememberemTheme.titleWithSuffix(
                context,
                'Trash',
                '${trashed.length}',
              ),
        actions: const [HomeButton()],
      ),
      body: trashed == null
          ? const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                minHeight: 3,
                semanticsLabel: 'Loading',
              ),
            )
          : trashed.isEmpty
          ? const EmptyState(
              title: 'Trash is empty.',
              help:
                  'People you delete wait here until you delete them forever.',
            )
          : _list(trashed),
    );
  }

  /// Grouped by when they were trashed, newest first.
  Widget _list(List<Memory> trashed) {
    final rows = <Object>[
      for (final group in DateGroups(
        widget.clock,
        withToday: true,
      ).group(trashed, (m) => m.trashedAt!)) ...[group.label, ...group.items],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is! Memory) {
          return SectionHeader(title: row as String, tinted: false);
        }
        return MemoryTile(
          memory: row,
          photo: widget.repository.photoFile(row),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Restore',
                filled: true,
                onPressed: () => _restore(row),
              ),
              IconButton(
                tooltip: 'Delete forever',
                icon: Icon(
                  Icons.delete_forever_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _purge(row),
              ),
            ],
          ),
        );
      },
    );
  }
}
