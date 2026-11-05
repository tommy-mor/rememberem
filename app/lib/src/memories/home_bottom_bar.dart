import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/bottom_action_bar.dart';
import '../app/rememberem_theme.dart';
import 'remembered_label.dart';

/// Along the bottom of Home: the two practice buttons, how much is
/// remembered, and "Meet someone", the largest target on the screen. Before
/// anyone is saved only Meet shows. It wraps rather than overflowing with
/// large text.
class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    required this.remembered,
    required this.canPlayFaces,
    required this.canPlayDetails,
    required this.showPractice,
    required this.onFaces,
    required this.onDetails,
    required this.onMeet,
  });

  final RememberedCount remembered;
  final bool canPlayFaces;
  final bool canPlayDetails;

  /// False before the list has loaded or while it is empty.
  final bool showPractice;
  final VoidCallback onFaces;
  final VoidCallback onDetails;
  final VoidCallback onMeet;

  /// Above the practice buttons.
  static const quizzesLabel = 'Quizzes to help you remember...';

  /// What a screen reader says for the Faces practice button.
  static const facesLabel =
      'Practice faces. Needs sight; Practice details works with a screen '
      'reader.';

  /// What a screen reader says for the Meet button.
  static const meetLabel = 'Meet someone';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final small = theme.textTheme.bodySmall;
    return Material(
      color: dark ? scheme.surfaceContainerHigh : RememberemTheme.paleGold,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: RememberemTheme.rule(theme))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RememberemTheme.gutter,
              6,
              RememberemTheme.gutter,
              6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showPractice)
                  Text(
                    quizzesLabel,
                    style: small?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                if (showPractice && !canPlayFaces)
                  Text(
                    'Name at least 4 different people to practice faces.',
                    style: small,
                  ),
                if (showPractice && !canPlayDetails)
                  Text(
                    'Add a detail and have 4 people to practice details.',
                    style: small,
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (showPractice)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          _practiceButton(
                            context,
                            label: 'Faces',
                            semanticsLabel: facesLabel,
                            icon: Icons.face_rounded,
                            onPressed: canPlayFaces ? onFaces : null,
                          ),
                          _practiceButton(
                            context,
                            label: 'Details',
                            icon: Icons.notes_rounded,
                            onPressed: canPlayDetails ? onDetails : null,
                          ),
                          if (!remembered.isNothing)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: RememberedLabel(remembered),
                            ),
                        ],
                      ),
                    Tooltip(
                      message: meetLabel,
                      excludeFromSemantics: true,
                      child: Semantics(
                        label: meetLabel,
                        button: true,
                        onTap: onMeet,
                        excludeSemantics: true,
                        child: FilledButton.icon(
                          onPressed: onMeet,
                          style: BottomActionBar.goldStyle,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Meet'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// An icon over its label, outlined away so only the text and icon show.
  Widget _practiceButton(
    BuildContext context, {
    required String label,
    String? semanticsLabel,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide.none,
        minimumSize: const Size(56, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          Text(
            label,
            semanticsLabel: semanticsLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
