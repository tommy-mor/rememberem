import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// What a kind of detail is for, and how the filters and the Details game
/// use it; opened from the "?" on a detail being edited.
class DetailHelpDialog extends StatelessWidget {
  const DetailHelpDialog({super.key, required this.kind});

  final DetailKind kind;

  static Future<void> show(BuildContext context, DetailKind kind) =>
      showDialog<void>(
        context: context,
        builder: (_) => DetailHelpDialog(kind: kind),
      );

  /// The help for [kind], one paragraph per entry.
  static List<String> textFor(DetailKind kind) => switch (kind) {
    DetailKind.fact => const [
      'Something true about the person: their job, their dog\'s name, '
          'what they love to talk about.',
      'The Details game shows a fact and asks whose it is. The '
          '"Details contain" filter finds everyone whose details mention '
          'a word.',
    ],
    DetailKind.happening => const [
      'Something that happened, with when and where: they got a new job, '
          'you met their kids at the park.',
      'Happenings come up in the Details game and on the timeline. The '
          '"Details contain" filter finds their words.',
    ],
    DetailKind.relationship => const [
      'Who this person is to someone else you know: their boss, partner '
          'or friend. Choose the other person, then the type.',
      'Both people show the link on their cards. Once you add a few words, '
          'the Details game shows it as "My boss is Jill" and asks who it is '
          'about.',
    ],
    DetailKind.anniversary => const [
      'A date that comes round every year: a birthday, a wedding, the day '
          'you first met. Choose the type and the first date.',
      'Notices remind you in the week before. The Anniversary filter finds '
          'everyone with one in a range of dates. The Details game asks about '
          'it once it has a type, a date and a few words.',
    ],
    DetailKind.tag => const [
      'A group you put people in: relatives, your book club, celebrities. '
          'Many people can share a tag. It may have a place and a date.',
      'The Tag filter lists everyone with a tag. The Details game never '
          'asks about tags, because many people share one. Choose or create '
          'a tag, or an entry with no words is not saved.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(kind.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final paragraph in textFor(kind))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(paragraph),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
