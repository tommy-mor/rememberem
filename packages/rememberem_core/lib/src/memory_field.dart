/// The single-line text fields shown for a person. Details are a separate
/// list of [Detail]s.
///
/// A [Memory] stores fields by [key] in an open map, so further facts
/// (age, interests, ...) can be added later without a schema change.
enum MemoryField {
  name('name', 'Name'),
  place('place', 'Place'),
  meeting('meeting', 'Meeting');

  const MemoryField(this.key, this.label);

  final String key;
  final String label;
}
