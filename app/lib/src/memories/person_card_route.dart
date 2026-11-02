import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'memory_edit_screen.dart';

/// Opens a person's card. Every screen that lists people uses this.
class PersonCardRoute extends MaterialPageRoute<void> {
  PersonCardRoute({required AppServices services, required Memory memory})
    : super(
        builder: (_) => MemoryEditScreen(
          memory: memory,
          repository: services.repository,
          dictation: services.dictation,
        ),
      );
}
