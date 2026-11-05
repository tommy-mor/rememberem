import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/section_header.dart';
import 'package:rememberem/src/practice/detail_prompt_block.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Capitals to look at, the original case to a screen reader, which would
/// otherwise spell upper-case words out letter by letter.
void main() {
  testWidgets('a section header is a header read in its own case, with its '
      'count', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionHeader(title: 'Facts', count: 2)),
      ),
    );
    expect(find.text('FACTS  2'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Facts, 2'));
    expect(node.flagsCollection.isHeader, isTrue);
    expect(find.bySemanticsLabel('FACTS  2'), findsNothing);
    handle.dispose();
  });

  testWidgets('the Details prompt chip is read in its own case', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final detail = Detail(id: 'd', text: 'Likes owls', at: DateTime.utc(2026));
    final prompt = DetailPrompt(detail, (_) => null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailPromptBlock(prompt: prompt, question: 'Who?'),
        ),
      ),
    );
    expect(find.text(prompt.caption.toUpperCase()), findsOneWidget);
    expect(find.bySemanticsLabel(prompt.caption), findsOneWidget);
    expect(find.bySemanticsLabel(prompt.caption.toUpperCase()), findsNothing);
    handle.dispose();
  });

  test('every indeterminate bar on a loading page says "Loading"', () {
    final bare = <String>[];
    final files = Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final text = file.readAsStringSync();
      for (final match in RegExp(
        r'LinearProgressIndicator\(([^)]*)\)',
      ).allMatches(text)) {
        final args = match.group(1)!;
        // A bar with a value is progress, read by its own screen; a bar
        // over a camera is decoration beside spoken text.
        if (args.contains('value:') || args.contains('color:')) continue;
        if (!args.contains("semanticsLabel: 'Loading'")) {
          bare.add(file.path);
        }
      }
    }
    expect(bare, isEmpty);
  });
}
