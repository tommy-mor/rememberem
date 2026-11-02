import 'memory.dart';

/// One person related to another: [person] is the other end, [label] the
/// relationship type as written ("brother", or blank).
class RelationshipLink {
  const RelationshipLink({
    required this.person,
    required this.label,
    required this.outgoing,
  });

  final Memory person;
  final String label;

  /// True if the relationship is written on this person's own record
  /// ("My brother is [person]"); false if it is on [person]'s record and
  /// points here ("My brother is this person").
  final bool outgoing;
}
