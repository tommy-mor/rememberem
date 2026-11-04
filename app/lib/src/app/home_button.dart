import 'package:flutter/material.dart';

/// A title-bar button back to the list, past every page in between. Pages
/// left this way close as Back would close them; [mayLeave], if given,
/// runs first (saving, or asking before throwing a photo away) and can
/// keep Fred where he is by answering false.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key, this.mayLeave, this.enabled = true});

  final Future<bool> Function()? mayLeave;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Home',
      icon: const Icon(Icons.home_outlined),
      onPressed: enabled ? () => _goHome(context) : null,
    );
  }

  Future<void> _goHome(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (mayLeave case final mayLeave? when !await mayLeave()) return;
    navigator.popUntil((route) => route.isFirst);
  }
}
