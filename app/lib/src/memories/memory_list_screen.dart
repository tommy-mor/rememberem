import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'memory_edit_screen.dart';

/// Home screen: everyone you have met, newest first.
class MemoryListScreen extends StatefulWidget {
  const MemoryListScreen({
    super.key,
    required this.services,
    required this.routeObserver,
    required this.onMeetSomeone,
  });

  final AppServices services;

  /// Tells the list when screens above it close, so it can refresh.
  final RouteObserver<ModalRoute<void>> routeObserver;
  final VoidCallback onMeetSomeone;

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> with RouteAware {
  late Future<List<Memory>> _memories = widget.services.repository.all();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {
      _memories = widget.services.repository.all();
    });
  }

  void _open(Memory memory) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryEditScreen(
          memory: memory,
          repository: widget.services.repository,
          dictation: widget.services.dictation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rememberem')),
      body: FutureBuilder<List<Memory>>(
        future: _memories,
        builder: (context, snapshot) {
          final memories = snapshot.data;
          if (memories == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (memories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No one yet.\n\nTap "Meet someone" to take a photo. '
                  'Tip: long-press the Rememberem icon and drag '
                  '"Meet someone" to your home screen for a one-tap shortcut.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              final name = memory.field(MemoryField.name);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: FileImage(
                    widget.services.repository.photoFile(memory),
                  ),
                ),
                title: Text(name.isEmpty ? 'Unnamed' : name),
                subtitle: Text(
                  [
                    memory.field(MemoryField.place),
                    memory.field(MemoryField.meeting),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                onTap: () => _open(memory),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onMeetSomeone,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Meet someone'),
      ),
    );
  }
}
