import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/home_button.dart';
import 'memory_tile.dart';

/// Picks the existing person to merge someone into. Pops with the chosen
/// [Memory], or null if Fred backs out.
class MergePickerScreen extends StatefulWidget {
  const MergePickerScreen({
    super.key,
    required this.repository,
    required this.excludeId,
  });

  final MemoryRepository repository;

  /// The person being merged, who is never offered.
  final String excludeId;

  @override
  State<MergePickerScreen> createState() => _MergePickerScreenState();
}

class _MergePickerScreenState extends State<MergePickerScreen> {
  late final Future<List<Memory>> _people = widget.repository.all();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge with…'),
        actions: const [HomeButton()],
      ),
      body: FutureBuilder<List<Memory>>(
        future: _people,
        builder: (context, snapshot) {
          final people = [
            for (final m in snapshot.data ?? <Memory>[])
              if (m.id != widget.excludeId) m,
          ];
          if (snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (people.isEmpty) {
            return const Center(child: Text('No one else to merge with.'));
          }
          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) => MemoryTile(
              memory: people[index],
              photo: widget.repository.photoFile(people[index]),
              onTap: () => Navigator.of(context).pop(people[index]),
            ),
          );
        },
      ),
    );
  }
}
