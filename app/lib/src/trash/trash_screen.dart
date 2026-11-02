import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/memory_tile.dart';
import 'purge_confirm_dialog.dart';

/// People moved to the trash. Each can be restored, or deleted forever
/// after a confirmation.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key, required this.repository});

  final MemoryRepository repository;

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
      appBar: AppBar(title: const Text('Trash')),
      body: trashed == null
          ? const Center(child: CircularProgressIndicator())
          : trashed.isEmpty
          ? const Center(child: Text('Trash is empty.'))
          : ListView.builder(
              itemCount: trashed.length,
              itemBuilder: (context, index) {
                final memory = trashed[index];
                return MemoryTile(
                  memory: memory,
                  photo: widget.repository.photoFile(memory),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Restore',
                        icon: const Icon(Icons.restore_from_trash),
                        onPressed: () => _restore(memory),
                      ),
                      IconButton(
                        tooltip: 'Delete forever',
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () => _purge(memory),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
