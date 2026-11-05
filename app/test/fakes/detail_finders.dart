import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/detail_list_editor.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// The "+" on a kind's heading.
Finder addDetailButton(DetailKind kind) =>
    find.byTooltip(DetailListEditor.addLabel(kind));

/// The "+" for a kind named as the old buttons were: "fact", "tag".
Finder addDetailButtonNamed(String kind) => addDetailButton(
  DetailKind.values.firstWhere((k) => k.label.toLowerCase() == kind),
);

/// The expander on a closed card, named by [DetailSummary.spokenName].
Finder openToggle(String name) =>
    find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Open $name');

/// The description field of an open card.
Finder descriptionField() => find.widgetWithText(TextField, 'DESCRIPTION');

/// A kind's tinted header on the card: its title in capitals, then the
/// count.
Finder detailHeading(DetailKind kind) =>
    find.textContaining(kind.plural.toUpperCase());
