/// The text fields shown when a new person is captured.
///
/// A [Memory] stores fields by [key] in an open map, so further facts
/// (age, interests, ...) can be added later without a schema change.
enum MemoryField {
  name('name', 'Name'),
  place('place', 'Place'),
  meeting('meeting', 'Meeting'),
  details('details', 'Details');

  const MemoryField(this.key, this.label);

  final String key;
  final String label;
}
